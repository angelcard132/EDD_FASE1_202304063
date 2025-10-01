unit json_loader;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  fpjson, jsonparser,
  listasimple2, cola2, arbol_avl, arbol_b;

{ Cargar usuarios desde JSON estándar }
procedure CargarUsuariosDesdeJSON(const archivo: String; var lista: TListaSimple);

{ Cargar correos programados desde JSON estándar → Cola }
procedure CargarCorreosProgramadosDesdeJSON(const archivo: String; var programados: TCola);

{ Cargar correos borradores desde JSON estándar → AVL }
procedure CargarBorradoresDesdeJSON(const archivo: String; var borradores: PCorreoAVL);

{ Cargar correos favoritos desde JSON estándar → Árbol B }
procedure CargarFavoritosDesdeJSON(const archivo: String; var favoritos: PNodoB);

{ Carga masiva unificada de usuarios.json y correos.json }
procedure CargaMasivaDesdeJSON(
  const usuariosFile, correosFile: String;
  var lista: TListaSimple; var programados: TCola; var borradores: PCorreoAVL; var favoritos: PNodoB
);

{ Autenticación: usa datos cargados desde usuarios.json }
function ValidarLogin(const email, password: String): Boolean;
function NombreDeEmail(const email: String): String;

{ Registrar nuevas credenciales para usuarios recién creados }
procedure RegistrarCredencialesUsuario(const email, password, nombre: String);

{ Gestión de estados de correos }
function ObtenerEstadoCorreo(correoID: Integer): String;
procedure EstablecerEstadoCorreo(correoID: Integer; const estado: String);

implementation

var
  GPassByEmail: TStringList;   // email -> password
  GNameByEmail: TStringList;   // email -> nombre
  GEstadosCorreos: TStringList; // correoID -> estado

function ValidarLogin(const email, password: String): Boolean;
var
  storedPass: String;
  i: Integer;
begin
  Result := False;
  
  WriteLn('DEBUG json_loader - Validando email: "', email, '" password: "', password, '"');
  
  if (GPassByEmail = nil) then
  begin
    WriteLn('DEBUG json_loader - GPassByEmail es nil');
    Exit;
  end;
  
  WriteLn('DEBUG json_loader - Cantidad de passwords almacenados: ', GPassByEmail.Count);
  
  if GPassByEmail.Count > 0 then
  begin
    WriteLn('DEBUG json_loader - Passwords almacenados:');
    for i := 0 to GPassByEmail.Count - 1 do
      WriteLn('  ', GPassByEmail.Names[i], ' = ', GPassByEmail.ValueFromIndex[i]);
  end;
  
  storedPass := GPassByEmail.Values[email];
  WriteLn('DEBUG json_loader - Password almacenado para "', email, '": "', storedPass, '"');
  
  Result := (storedPass = password) and (password <> '');
  WriteLn('DEBUG json_loader - Resultado: ', Result);
end;

procedure CargarUsuariosDesdeJSON(const archivo: String; var lista: TListaSimple);
var
  data: TStringList;
  json: TJSONData;
  arr: TJSONArray;
  obj: TJSONObject;
  i: Integer;
  email, pass, nombre: String;
begin
  if not FileExists(archivo) then
  begin
    WriteLn('❌ No existe el archivo: ', archivo);
    Exit;
  end;

  // Reiniciar almacenes de autenticación
  if GPassByEmail <> nil then GPassByEmail.Clear;
  if GNameByEmail <> nil then GNameByEmail.Clear;

  data := TStringList.Create;
  try
    data.LoadFromFile(archivo);
    json := GetJSON(data.Text);
    try
      arr := TJSONArray(json.FindPath('usuarios'));
      if arr <> nil then
      begin
        WriteLn('📂 Cargando usuarios...');
        for i := 0 to arr.Count - 1 do
        begin
          obj := arr.Objects[i];
          // Datos
          email := obj.Get('email', '');
          pass := obj.Get('password', '');
          nombre := obj.Get('nombre', '');

          // Persistir en lista visible para el sistema
          AgregarUsuario(lista,
            obj.Get('id', 0),
            nombre,
            obj.Get('usuario', ''),
            email,
            obj.Get('telefono', '')
          );

          // Persistir credenciales y nombre (para login)
          if email <> '' then
          begin
            GPassByEmail.Values[email] := pass;
            GNameByEmail.Values[email] := nombre;
            WriteLn('DEBUG - Almacenando: ', email, ' -> ', pass);
          end;

          WriteLn('  ✅ Usuario cargado: ', email);
        end;
        WriteLn('📊 Total usuarios: ', arr.Count);
        WriteLn('📊 Passwords almacenados: ', GPassByEmail.Count);
      end;
    finally
      json.Free;
    end;
  finally
    data.Free;
  end;
end;

function ObtenerEstadoCorreo(correoID: Integer): String;
var
  idStr: String;
begin  
  idStr := IntToStr(correoID);
  if GEstadosCorreos <> nil then
    Result := GEstadosCorreos.Values[idStr]
  else
    Result := 'NL'; // Default: No Leído
  
  if Result = '' then
    Result := 'NL';
end;

procedure EstablecerEstadoCorreo(correoID: Integer; const estado: String);
var
  idStr: String;
begin
  idStr := IntToStr(correoID);
  if GEstadosCorreos <> nil then
  begin
    GEstadosCorreos.Values[idStr] := estado;
    WriteLn('DEBUG - Estado establecido para correo ID ', correoID, ': ', estado);
  end;
end;

procedure ActualizarEstadoCorreoEnCola(var programados: TCola; correoID: Integer; nuevoEstado: String);
begin
  EstablecerEstadoCorreo(correoID, nuevoEstado);
end;

procedure CargarCorreosProgramadosDesdeJSON(const archivo: String; var programados: TCola);
var
  data: TStringList;
  json: TJSONData;
  arr: TJSONArray;
  obj: TJSONObject;
  i: Integer;
  correoID: Integer;
  estado: String;
begin
  if not FileExists(archivo) then
  begin
    WriteLn('❌ No existe el archivo: ', archivo);
    Exit;
  end;

  data := TStringList.Create;
  try
    data.LoadFromFile(archivo);
    json := GetJSON(data.Text);
    try
      arr := TJSONArray(json.FindPath('correos'));
      if arr <> nil then
      begin
        WriteLn('📂 Cargando correos programados...');
        for i := 0 to arr.Count - 1 do
        begin
          obj := arr.Objects[i];
          correoID := obj.Get('id', 0);
          estado := obj.Get('estado', 'NL');
          
          // Encolar normalmente
          Encolar(programados,
            correoID,
            obj.Get('remitente', ''),
            obj.Get('destinatario', ''),
            obj.Get('asunto', ''),
            obj.Get('mensaje', '')
          );
          
          // Actualizar el estado después de encolar
          ActualizarEstadoCorreoEnCola(programados, correoID, estado);
          
          WriteLn('  📧 Programado: ', obj.Get('asunto', ''), ' - Estado: ', estado);
        end;
        WriteLn('📊 Total programados: ', arr.Count);
      end;
    finally
      json.Free;
    end;
  finally
    data.Free;
  end;
end;

procedure CargarBorradoresDesdeJSON(const archivo: String; var borradores: PCorreoAVL);
var
  data: TStringList;
  json: TJSONData;
  arr: TJSONArray;
  obj: TJSONObject;
  i: Integer;
begin
  if not FileExists(archivo) then
  begin
    WriteLn('❌ No existe el archivo: ', archivo);
    Exit;
  end;

  data := TStringList.Create;
  try
    data.LoadFromFile(archivo);
    json := GetJSON(data.Text);
    try
      arr := TJSONArray(json.FindPath('correos'));
      if arr <> nil then
      begin
        WriteLn('📂 Cargando borradores...');
        for i := 0 to arr.Count - 1 do
        begin
          obj := arr.Objects[i];
          borradores := arbol_avl.Insertar(borradores,
            obj.Get('id', 0),
            obj.Get('remitente', ''),
            obj.Get('destinatario', ''),
            obj.Get('asunto', ''),
            obj.Get('mensaje', '')
          );
          WriteLn('  📝 Borrador: ', obj.Get('asunto', ''));
        end;
        WriteLn('📊 Total borradores: ', arr.Count);
      end;
    finally
      json.Free;
    end;
  finally
    data.Free;
  end;
end;

procedure CargarFavoritosDesdeJSON(const archivo: String; var favoritos: PNodoB);
var
  data: TStringList;
  json: TJSONData;
  arr: TJSONArray;
  obj: TJSONObject;
  i: Integer;
  correo: TCorreoB;
begin
  if not FileExists(archivo) then
  begin
    WriteLn('❌ No existe el archivo: ', archivo);
    Exit;
  end;

  data := TStringList.Create;
  try
    data.LoadFromFile(archivo);
    json := GetJSON(data.Text);
    try
      arr := TJSONArray(json.FindPath('correos'));
      if arr <> nil then
      begin
        WriteLn('📂 Cargando favoritos...');
        for i := 0 to arr.Count - 1 do
        begin
          obj := arr.Objects[i];
          correo.id := obj.Get('id', 0);
          correo.remitente := obj.Get('remitente', '');
          correo.destinatario := obj.Get('destinatario', '');
          correo.asunto := obj.Get('asunto', '');
          correo.mensaje := obj.Get('mensaje', '');
          arbol_b.Insertar(favoritos, correo);
          WriteLn('  ⭐ Favorito: ', correo.asunto);
        end;
        WriteLn('📊 Total favoritos: ', arr.Count);
      end;
    finally
      json.Free;
    end;
  finally
    data.Free;
  end;
end;

procedure CargaMasivaDesdeJSON(
  const usuariosFile, correosFile: String;
  var lista: TListaSimple; var programados: TCola; var borradores: PCorreoAVL; var favoritos: PNodoB
);
var
  data: TStringList;
  json: TJSONData;
  arr: TJSONArray;
  obj: TJSONObject;
  i: Integer;
  email, pass, nombre: String;
  correoID: Integer;
  estado, remitente, destinatario, asunto, mensaje: String;
begin
  WriteLn('🚀 Iniciando carga masiva...');
  
  // Usuarios
  if FileExists(usuariosFile) then
  begin
    if GPassByEmail <> nil then GPassByEmail.Clear;
    if GNameByEmail <> nil then GNameByEmail.Clear;

    data := TStringList.Create;
    try
      data.LoadFromFile(usuariosFile);
      json := GetJSON(data.Text);
      try
        arr := TJSONArray(json.FindPath('usuarios'));
        if arr <> nil then
        begin
          WriteLn('📂 Cargando usuarios...');
          for i := 0 to arr.Count - 1 do
          begin
            obj := arr.Objects[i];
            email := obj.Get('email', '');
            pass := obj.Get('password', '');
            nombre := obj.Get('nombre', '');
            
            AgregarUsuario(lista,
              obj.Get('id', 0),
              nombre,
              obj.Get('usuario', ''),
              email,
              obj.Get('telefono', '')
            );

            if email <> '' then
            begin
              GPassByEmail.Values[email] := pass;
              GNameByEmail.Values[email] := nombre;
              WriteLn('DEBUG - Usuario almacenado: ', email, ' -> ', pass);
            end;
          end;
          WriteLn('📊 Total usuarios: ', arr.Count);
        end;
      finally
        json.Free;
      end;
    finally
      data.Free;
    end;
  end
  else
    WriteLn('❌ No existe el archivo de usuarios: ', usuariosFile);

  // Correos con logging detallado
  if FileExists(correosFile) then
  begin
    if GEstadosCorreos <> nil then GEstadosCorreos.Clear;
    
    data := TStringList.Create;
    try
      data.LoadFromFile(correosFile);
      WriteLn('📄 Contenido del archivo de correos (primeras 500 chars):');
      WriteLn(Copy(data.Text, 1, 500));
      
      json := GetJSON(data.Text);
      try
        arr := TJSONArray(json.FindPath('correos'));
        if arr <> nil then
        begin
          WriteLn('📂 Cargando correos... Total encontrados: ', arr.Count);
          for i := 0 to arr.Count - 1 do
          begin
            obj := arr.Objects[i];
            correoID := obj.Get('id', 0);
            estado := obj.Get('estado', 'NL');
            remitente := obj.Get('remitente', '');
            destinatario := obj.Get('destinatario', '');
            asunto := obj.Get('asunto', '');
            mensaje := obj.Get('mensaje', '');

            WriteLn('DEBUG - Procesando correo #', i + 1);
            WriteLn('  ID: ', correoID);
            WriteLn('  Remitente: "', remitente, '"');
            WriteLn('  Destinatario: "', destinatario, '"');
            WriteLn('  Asunto: "', asunto, '"');
            WriteLn('  Estado: "', estado, '"');

            // Cola (programados) - todos los correos van aquí
            Encolar(programados, correoID, remitente, destinatario, asunto, mensaje);
            EstablecerEstadoCorreo(correoID, estado);

            // AVL (borradores) - todos los correos van aquí para que estén disponibles
            borradores := arbol_avl.Insertar(borradores, correoID, remitente, destinatario, asunto, mensaje);

            // Árbol B (favoritos) - NO cargar automáticamente, solo por acción del usuario
            // REMOVIDO: No insertar correos automáticamente en favoritos
            // El usuario los agregará manualmente desde la bandeja de entrada
            
            WriteLn('  ✅ Correo cargado ID: ', correoID, ' - Estado: ', estado);
          end;
          WriteLn('📊 Total correos procesados: ', arr.Count);
          WriteLn('ℹ️ Favoritos inicializados vacíos - se llenan por acción del usuario');
        end
        else
          WriteLn('❌ No se encontró el array "correos" en el JSON');
      finally
        json.Free;
      end;
    finally
      data.Free;
    end;
  end
  else
    WriteLn('❌ No existe el archivo de correos: ', correosFile);

  WriteLn('✅ Carga masiva finalizada.');
end;

function NombreDeEmail(const email: String): String;
begin
  if GNameByEmail <> nil then
    Result := GNameByEmail.Values[email]
  else
    Result := '';
end;

procedure RegistrarCredencialesUsuario(const email, password, nombre: String);
begin
  if (GPassByEmail <> nil) and (GNameByEmail <> nil) then
  begin
    GPassByEmail.Values[email] := password;
    GNameByEmail.Values[email] := nombre;
    WriteLn('DEBUG - Credenciales registradas para: ', email);
  end;
end;

initialization
  GPassByEmail := TStringList.Create;
  GPassByEmail.CaseSensitive := False;
  GPassByEmail.Sorted := False;
  GPassByEmail.NameValueSeparator := '=';

  GNameByEmail := TStringList.Create;
  GNameByEmail.CaseSensitive := False;
  GNameByEmail.Sorted := False;
  GNameByEmail.NameValueSeparator := '=';

  GEstadosCorreos := TStringList.Create;
  GEstadosCorreos.CaseSensitive := False;
  GEstadosCorreos.Sorted := False;
  GEstadosCorreos.NameValueSeparator := '=';

finalization
  FreeAndNil(GPassByEmail);
  FreeAndNil(GNameByEmail);
  FreeAndNil(GEstadosCorreos);

end.
  FreeAndNil(GNameByEmail);
  FreeAndNil(GEstadosCorreos);

end.
end.
    WriteLn('❌ Error: No se encontró el archivo ', rutaArchivo);
    Exit;
  end;

  // Inicializar variables de control
  dentroArray := False;
  dentroObjeto := False;
  nivel := 0;
  esperandoValor := False;
  enString := False;
  
  // Inicializar campos del correo
  id := 0;
  remitente := '';
  destinatario := '';
  estado := '';
  asunto := '';
  mensaje := '';
  campoActual := '';
  valorActual := '';

  try
    AssignFile(archivo, rutaArchivo);
    Reset(archivo);
    
    while not EOF(archivo) do
    begin
      ReadLn(archivo, lineaActual);
      lineaActual := Trim(lineaActual);
      
      if lineaActual = '' then Continue;
      
      // Procesar cada carácter de la línea
      i := 1;
      while i <= Length(lineaActual) do
      begin
        c := lineaActual[i];
        
        case c of
          '{':
            begin
              Inc(nivel);
              if (nivel = 2) and dentroArray then
              begin
                dentroObjeto := True;
                // Reiniciar campos para nuevo correo
                id := 0;
                remitente := '';
                destinatario := '';
                estado := '';
                asunto := '';
                mensaje := '';
              end;
            end;
            
          '}':
            begin
              Dec(nivel);
              if dentroObjeto and (nivel = 1) then
              begin
                // Fin del objeto correo - procesarlo de forma segura
                if (id > 0) and (remitente <> '') and (destinatario <> '') then
                begin
                  try
                    // Establecer estado de forma segura
                    if estado <> '' then
                    begin
                      EstablecerEstadoCorreo(id, estado);
                    end
                    else
                    begin
                      EstablecerEstadoCorreo(id, 'NL');
                    end;
                    
                    // Encolar en programados de forma segura
                    try
                      Encolar(programados, id, remitente, destinatario, asunto, mensaje);
                    except
                      on E: Exception do
                      begin
                        WriteLn('❌ Error al encolar correo ID ', id, ': ', E.Message);
                        Continue;
                      end;
                    end;
                    
                    // Insertar en AVL de forma segura
                    try
                      borradores := arbol_avl.Insertar(borradores, id, remitente, destinatario, asunto, mensaje);
                    except
                      on E: Exception do
                      begin
                        WriteLn('❌ Error al insertar en AVL correo ID ', id, ': ', E.Message);
                      end;
                    end;
                    
                    // Insertar en Árbol B de forma segura
                    try
                      correoB.id := id;
                      correoB.remitente := remitente;
                      correoB.destinatario := destinatario;
                      correoB.asunto := asunto;
                      correoB.mensaje := mensaje;
                      arbol_b.Insertar(favoritos, correoB);
                    except
                      on E: Exception do
                      begin
                        WriteLn('❌ Error al insertar en Árbol B correo ID ', id, ': ', E.Message);
                      end;
                    end;
                    
                    WriteLn('  📧 Correo cargado ID: ', id, ' - Estado: ', ObtenerEstadoCorreo(id));
                  except
                    on E: Exception do
                    begin
                      WriteLn('❌ Error general al procesar correo ID ', id, ': ', E.Message);
                      Continue;
                    end;
                  end;
                end
                else
                begin
                  WriteLn('❌ Correo incompleto ignorado - ID: ', id, ' Remitente: ', remitente, ' Destinatario: ', destinatario);
                end;
                dentroObjeto := False;
              end;
            end;
            
          '[':
            if nivel = 1 then
              dentroArray := True;
              
          ']':
            if nivel = 1 then
              dentroArray := False;
              
          '"':
            begin
              enString := not enString;
              if not enString then
              begin
                // Fin de string - procesar campo:valor
                if esperandoValor and (campoActual <> '') then
                begin
                  // Asignar valor al campo correspondiente
                  if campoActual = 'id' then
                  begin
                    try
                      id := StrToInt(valorActual);
                    except
                      id := 0;
                      WriteLn('❌ Error al convertir ID: ', valorActual);
                    end;
                  end
                  else if campoActual = 'remitente' then
                    remitente := valorActual
                  else if campoActual = 'destinatario' then
                    destinatario := valorActual
                  else if campoActual = 'estado' then
                    estado := valorActual
                  else if campoActual = 'asunto' then
                    asunto := valorActual
                  else if campoActual = 'mensaje' then
                    mensaje := valorActual;
                    
                  esperandoValor := False;
                  valorActual := '';
                end
                else
                begin
                  campoActual := valorActual;
                  valorActual := '';
                end;
              end;
            end;
            
          ':':
            if not enString then
              esperandoValor := True;
              
          ',', #10, #13:
            // Ignorar separadores fuera de strings
            if not enString then
            begin
              // No hacer nada especial
            end;
            
          else
            if enString then
              valorActual := valorActual + c;
        end;
        
        Inc(i);
      end;
    end;
    
    CloseFile(archivo);
    WriteLn('✅ Correos cargados exitosamente');
    
  except
    on E: Exception do
    begin
      WriteLn('❌ Error crítico al cargar correos: ', E.Message);
      try
        CloseFile(archivo);
      except
        // Ignorar errores al cerrar archivo
      end;
    end;
  end;
end;

initialization
  GPassByEmail := TStringList.Create;
  GPassByEmail.CaseSensitive := False;
  GPassByEmail.Sorted := False;
  GPassByEmail.NameValueSeparator := '=';

  GNameByEmail := TStringList.Create;
  GNameByEmail.CaseSensitive := False;
  GNameByEmail.Sorted := False;
  GNameByEmail.NameValueSeparator := '=';

  GEstadosCorreos := TStringList.Create;
  GEstadosCorreos.CaseSensitive := False;
  GEstadosCorreos.Sorted := False;
  GEstadosCorreos.NameValueSeparator := '=';

finalization
  FreeAndNil(GPassByEmail);
  FreeAndNil(GNameByEmail);
  FreeAndNil(GEstadosCorreos);

end.
