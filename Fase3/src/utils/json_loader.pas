unit json_loader;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  fpjson, jsonparser,
  listasimple2, cola2, arbol_avl, arbol_b;

{ Cargar usuarios desde JSON estándar }
procedure CargarUsuariosDesdeJSON(const archivo: String; var lista: TListaSimple);

{ Nueva función simplificada para cargar SOLO correos a la cola }
procedure CargarCorreosSimplificado(const archivo: String; var programados: TCola);

{ Carga masiva unificada - SIMPLIFICADA }
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

{ ✅ IMPLEMENTACIÓN COMPLETA de CargarCorreosSimplificado }
procedure CargarCorreosSimplificado(const archivo: String; var programados: TCola);
var
  data: TStringList;
  json: TJSONData;
  arr: TJSONArray;
  obj: TJSONObject;
  i: Integer;
  correoID: Integer;
  estado: String;
  remitente, destinatario, asunto, mensaje: String;
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
        WriteLn('📂 Cargando correos SIMPLIFICADO (solo NL/L)...');
        for i := 0 to arr.Count - 1 do
        begin
          try
            obj := arr.Objects[i];
            correoID := obj.Get('id', 0);
            
            // Obtener datos básicos
            remitente := obj.Get('remitente', '');
            destinatario := obj.Get('destinatario', '');
            asunto := obj.Get('asunto', '');
            mensaje := obj.Get('mensaje', '');
            estado := obj.Get('estado', 'NL');
            
            // ✅ SOLO PERMITIR ESTADOS NL (No Leído) y L (Leído)
            if (estado <> 'NL') and (estado <> 'L') then
            begin
              WriteLn('⚠️ Estado "', estado, '" no válido para ID ', correoID, ' -> cambiando a NL');
              estado := 'NL';
            end;
            
            // Validar datos básicos
            if (correoID <= 0) or (Length(remitente) = 0) or (Length(destinatario) = 0) then
            begin
              WriteLn('⚠️ Correo ID ', correoID, ' inválido, omitiendo...');
              Continue;
            end;
            
            // ✅ SOLO ENCOLAR EN PROGRAMADOS
            Encolar(programados, correoID, remitente, destinatario, asunto, mensaje);
            
            // Establecer estado (solo NL o L)
            EstablecerEstadoCorreo(correoID, estado);
            
            WriteLn('📧 Correo cargado: ID ', correoID, ' Estado: ', estado);
            
          except
            on E: Exception do
              WriteLn('❌ Error procesando correo ', i + 1, ': ', E.Message);
          end;
        end;
        WriteLn('📊 Total correos cargados en cola: ', arr.Count);
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
  WriteLn('🔄 Iniciando carga masiva simplificada...');
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
  
  // ✅ SOLO CARGAR USUARIOS Y CORREOS A LA COLA
  WriteLn('👥 Cargando usuarios...');
  if FileExists(usuariosFile) then
    CargarUsuariosDesdeJSON(usuariosFile, lista)
  else
    WriteLn('❌ Error: Archivo de usuarios no encontrado: ', usuariosFile);
  
  WriteLn('📧 Cargando correos SOLO a cola...');
  if FileExists(correosFile) then
    CargarCorreosSimplificado(correosFile, programados)
  else
    WriteLn('❌ Error: Archivo de correos no encontrado: ', correosFile);
  
  // ✅ NO cargar borradores ni favoritos desde JSON
  WriteLn('📝 Borradores: Inicializados vacíos (se crean dinámicamente)');
  WriteLn('⭐ Favoritos: Inicializados vacíos (se agregan desde bandeja)');
  
  // Mostrar resumen de carga
  WriteLn('');
  WriteLn('📊 RESUMEN DE CARGA MASIVA SIMPLIFICADA:');
  WriteLn('=========================================');
  WriteLn('👥 Usuarios cargados: ', ContarElementosLista(lista));
  WriteLn('📧 Correos en cola: ', ContarCorreosEnCola(programados));
  WriteLn('📝 Borradores: 0 (vacío inicial)');
  WriteLn('⭐ Favoritos: 0 (vacío inicial)');
  WriteLn('=========================================');
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
