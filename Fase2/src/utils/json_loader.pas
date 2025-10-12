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

{ Limpiar estructuras }
procedure LimpiarLista(var lista: TListaSimple);
procedure LimpiarCola(var cola: TCola);

{ Función auxiliar para contar elementos }
function ContarElementosLista(var lista: TListaSimple): Integer;
function ContarCorreosEnCola(var cola: TCola): Integer;

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

function LimpiarStringSeguro(const s: String): String;
var
  i: Integer;
  c: Char;
begin
  Result := '';
  if Length(s) = 0 then 
  begin
    Result := 'vacio';
    Exit;
  end;
  
  for i := 1 to Length(s) do
  begin
    c := s[i];
    // Solo permitir caracteres ASCII básicos
    if (c >= 'a') and (c <= 'z') then
      Result := Result + c
    else if (c >= 'A') and (c <= 'Z') then
      Result := Result + c
    else if (c >= '0') and (c <= '9') then
      Result := Result + c
    else if (c = ' ') or (c = '.') or (c = ',') or (c = ':') or (c = '@') or (c = '-') or (c = '_') then
      Result := Result + c
    else if c = 'ñ' then
      Result := Result + 'n'
    else if c = 'ó' then
      Result := Result + 'o'
    else if c = 'í' then
      Result := Result + 'i'
    else if c = 'á' then
      Result := Result + 'a'
    else if c = 'é' then
      Result := Result + 'e'
    else if c = 'ú' then
      Result := Result + 'u'
    else if c = '¿' then
      Result := Result + '?'
    else if c = '¡' then
      Result := Result + '!'
    else
      Result := Result + '?';
  end;
  
  // Asegurar que no esté vacío
  if Result = '' then
    Result := 'texto_limpio';
end;

function ValidarYLimpiarCorreo(const correo: TCorreoB): TCorreoB;
var
  correoLimpio: TCorreoB;
begin
  correoLimpio.id := correo.id;
  
  // Limpiar y validar strings con límites estrictos
  correoLimpio.remitente := Copy(LimpiarStringSeguro(correo.remitente), 1, 50);
  correoLimpio.destinatario := Copy(LimpiarStringSeguro(correo.destinatario), 1, 50);
  correoLimpio.asunto := Copy(LimpiarStringSeguro(correo.asunto), 1, 80);
  correoLimpio.mensaje := Copy(LimpiarStringSeguro(correo.mensaje), 1, 200);
  
  // Validar que no estén vacíos
  if correoLimpio.remitente = '' then correoLimpio.remitente := 'remitente_desconocido';
  if correoLimpio.destinatario = '' then correoLimpio.destinatario := 'destinatario_desconocido';
  if correoLimpio.asunto = '' then correoLimpio.asunto := 'sin_asunto';
  if correoLimpio.mensaje = '' then correoLimpio.mensaje := 'sin_mensaje';
  
  Result := correoLimpio;
end;

{ Cargar correos desde JSON estándar a todas las estructuras }
procedure CargarCorreosDesdeJSON(const archivo: String; var programados: TCola; var borradores: PCorreoAVL; var favoritos: PNodoB);
var
  data: TStringList;
  json: TJSONData;
  arr: TJSONArray;
  obj: TJSONObject;
  i: Integer;
  correoID: Integer;
  estado: String;
  correo: TCorreoB;
  remitente, destinatario, asunto, mensaje: String;
  exitosoCola, exitosoAVL, exitosoBTree: Boolean;
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
        WriteLn('📂 Cargando correos con validación mejorada...');
        for i := 0 to arr.Count - 1 do
        begin
          try
            obj := arr.Objects[i];
            correoID := obj.Get('id', 0);
            
            // Obtener strings de forma muy segura
            remitente := LimpiarStringSeguro(obj.Get('remitente', ''));
            destinatario := LimpiarStringSeguro(obj.Get('destinatario', ''));
            asunto := LimpiarStringSeguro(obj.Get('asunto', ''));
            mensaje := LimpiarStringSeguro(obj.Get('mensaje', ''));
            estado := obj.Get('estado', 'NL');
            
            // Validar datos básicos
            if (correoID <= 0) or (Length(remitente) = 0) or (Length(destinatario) = 0) then
            begin
              WriteLn('⚠️ Correo ID ', correoID, ' inválido, omitiendo...');
              Continue;
            end;
            
            exitosoCola := False;
            exitosoAVL := False;
            exitosoBTree := False;
            
            // Insertar en Cola (más simple y confiable)
            try
              Encolar(programados, correoID, remitente, destinatario, asunto, mensaje);
              exitosoCola := True;
              WriteLn('✓ Cola: Correo ', correoID, ' agregado');
            except
              on E: Exception do
                WriteLn('❌ Error en cola correo ', correoID, ': ', E.Message);
            end;
            
            // Solo insertar en AVL si la cola fue exitosa
            if exitosoCola then
            begin
              try
                if borradores <> nil then
                  borradores := arbol_avl.Insertar(borradores, correoID, remitente, destinatario, asunto, mensaje);
                if borradores <> nil then
                begin
                  exitosoAVL := True;
                  WriteLn('✓ AVL: Correo ', correoID, ' agregado');
                end
                else
                  WriteLn('❌ AVL devolvió nil para correo ', correoID);
              except
                on E: Exception do
                  WriteLn('❌ Error en AVL correo ', correoID, ': ', E.Message);
              end;
            end;
            
            // Solo insertar en B-Tree si ambos anteriores fueron exitosos
            if exitosoCola then
            begin
              try
                // Preparar estructura para B-Tree con límites estrictos
                correo.id := correoID;
                correo.remitente := Copy(remitente, 1, 30);
                correo.destinatario := Copy(destinatario, 1, 30);
                correo.asunto := Copy(asunto, 1, 50);
                correo.mensaje := Copy(mensaje, 1, 100);
                
                arbol_b.Insertar(favoritos, correo);
                exitosoBTree := True;
                WriteLn('✓ B-Tree: Correo ', correoID, ' agregado');
              except
                on E: Exception do
                  WriteLn('❌ Error en B-Tree correo ', correoID, ': ', E.Message);
              end;
            end;
            
            // Establecer estado solo si al menos la cola fue exitosa
            if exitosoCola then
            begin
              try
                EstablecerEstadoCorreo(correoID, estado);
              except
                on E: Exception do
                  WriteLn('❌ Error estableciendo estado correo ', correoID, ': ', E.Message);
              end;
            end;
            
            if exitosoCola then
              WriteLn('📧 Correo procesado: ', correoID, ' (Cola:✓ AVL:', exitosoAVL, ' B-Tree:', exitosoBTree, ')');
              
          except
            on E: Exception do
            begin
              WriteLn('❌ Error general procesando correo ', i + 1, ': ', E.Message);
            end;
          end;
        end;
        WriteLn('📊 Total correos procesados: ', arr.Count);
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
begin
  WriteLn('🔄 Iniciando carga masiva desde JSON...');
  WriteLn('📁 Usuarios: ', usuariosFile);
  WriteLn('📁 Correos: ', correosFile);
  
  // Limpiar estructuras antes de cargar
  WriteLn('🧹 Limpiando estructuras existentes...');
  LimpiarLista(lista);
  LimpiarCola(programados);
  arbol_avl.LiberarArbol(borradores);
  arbol_b.LiberarArbol(favoritos);
  
  // Reinicializar completamente
  InicializarLista(lista);
  InicializarCola(programados);
  arbol_avl.Inicializar(borradores);
  arbol_b.Inicializar(favoritos);
  
  // Cargar usuarios primero
  WriteLn('👥 Cargando usuarios...');
  if FileExists(usuariosFile) then
    CargarUsuariosDesdeJSON(usuariosFile, lista)
  else
    WriteLn('❌ Error: Archivo de usuarios no encontrado');
  
  // Cargar correos después
  WriteLn('📧 Cargando correos...');
  if FileExists(correosFile) then
    CargarCorreosDesdeJSON(correosFile, programados, borradores, favoritos)
  else
    WriteLn('❌ Error: Archivo de correos no encontrado');
  
  // Mostrar resumen de carga
  WriteLn('');
  WriteLn('📊 RESUMEN DE CARGA MASIVA:');
  WriteLn('===========================');
  WriteLn('👥 Usuarios cargados: ', ContarElementosLista(lista));
  WriteLn('📧 Correos en cola: ', ContarCorreosEnCola(programados));
  WriteLn('📝 Borradores en AVL: ', arbol_avl.ContarNodos(borradores));
  WriteLn('⭐ Favoritos en B-Tree: ', arbol_b.ContarCorreos(favoritos));
  WriteLn('===========================');
  WriteLn('✅ Carga masiva completada exitosamente');
end;

// Función auxiliar para contar correos en la cola
function ContarCorreosEnCola(var cola: TCola): Integer;
var
  actual: cola2.PCorreo;
  contador: Integer;
begin
  contador := 0;
  actual := cola.frente;
  while actual <> nil do
  begin
    Inc(contador);
    actual := actual^.siguiente;
  end;
  ContarCorreosEnCola := contador;
end;

// Función auxiliar para contar usuarios en la lista
function ContarElementosLista(var lista: TListaSimple): Integer;
var
  actual: PUsuario;
  contador: Integer;
begin
  contador := 0;
  actual := lista.cabeza;
  while actual <> nil do
  begin
    Inc(contador);
    actual := actual^.siguiente;
  end;
  ContarElementosLista := contador;
end;

// Agregar función para limpiar completamente la lista
procedure LimpiarLista(var lista: TListaSimple);
var
  actual, temp: PUsuario;
begin
  actual := lista.cabeza;
  while actual <> nil do
  begin
    temp := actual^.siguiente;
    Dispose(actual);
    actual := temp;
  end;
  lista.cabeza := nil;
end;

// Agregar función para limpiar completamente la cola
procedure LimpiarCola(var cola: TCola);
var
  actual, temp: cola2.PCorreo;
begin
  actual := cola.frente;
  while actual <> nil do
  begin
    temp := actual^.siguiente;
    Dispose(actual);
    actual := temp;
  end;
  cola.frente := nil;
  cola.final := nil;
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
