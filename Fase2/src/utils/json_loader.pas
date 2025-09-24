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

implementation

var
  GPassByEmail: TStringList;   // email -> password
  GNameByEmail: TStringList;   // email -> nombre

function ValidarLogin(const email, password: String): Boolean;
var
  storedPass: String;
  i: Integer;
begin
  Result := False;
  
  WriteLn('DEBUG json_loader - Validando email: "', email, '" password: "', password, '"');
  
  // Método usando GPassByEmail directamente
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

procedure CargarCorreosProgramadosDesdeJSON(const archivo: String; var programados: TCola);
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
        WriteLn('📂 Cargando correos programados...');
        for i := 0 to arr.Count - 1 do
        begin
          obj := arr.Objects[i];
          Encolar(programados,
            obj.Get('id', 0),
            obj.Get('remitente', ''),
            obj.Get('destinatario', ''),
            obj.Get('asunto', ''),
            obj.Get('mensaje', '')
          );
          WriteLn('  📧 Programado: ', obj.Get('asunto', ''));
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
  correo: TCorreoB;
  email, pass, nombre: String;
begin
  // Usuarios - cargar con credenciales
  if FileExists(usuariosFile) then
  begin
    // Reiniciar almacenes de autenticación
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

            // Almacenar credenciales para login
            if email <> '' then
            begin
              GPassByEmail.Values[email] := pass;
              GNameByEmail.Values[email] := nombre;
              WriteLn('DEBUG - Almacenando: ', email, ' -> ', pass);
            end;
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
  end
  else
    WriteLn('❌ No existe el archivo de usuarios: ', usuariosFile);

  // Correos
  if FileExists(correosFile) then
  begin
    data := TStringList.Create;
    try
      data.LoadFromFile(correosFile);
      json := GetJSON(data.Text);
      try
        arr := TJSONArray(json.FindPath('correos'));
        if arr <> nil then
        begin
          WriteLn('📂 Cargando correos...');
          for i := 0 to arr.Count - 1 do
          begin
            obj := arr.Objects[i];

            // Cola (programados)
            Encolar(programados,
              obj.Get('id', 0),
              obj.Get('remitente', ''),
              obj.Get('destinatario', ''),
              obj.Get('asunto', ''),
              obj.Get('mensaje', '')
            );

            // AVL (borradores)
            borradores := arbol_avl.Insertar(borradores,
              obj.Get('id', 0),
              obj.Get('remitente', ''),
              obj.Get('destinatario', ''),
              obj.Get('asunto', ''),
              obj.Get('mensaje', '')
            );

            // Árbol B (favoritos)
            correo.id := obj.Get('id', 0);
            correo.remitente := obj.Get('remitente', '');
            correo.destinatario := obj.Get('destinatario', '');
            correo.asunto := obj.Get('asunto', '');
            correo.mensaje := obj.Get('mensaje', '');
            arbol_b.Insertar(favoritos, correo);
          end;
          WriteLn('📊 Total correos: ', arr.Count);
        end;
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

finalization
  FreeAndNil(GPassByEmail);
  FreeAndNil(GNameByEmail);

end.
  GPassByEmail.Sorted := False;
  GPassByEmail.NameValueSeparator := '=';

  GNameByEmail := TStringList.Create;
  GNameByEmail.CaseSensitive := False;
  GNameByEmail.Sorted := False;
  GNameByEmail.NameValueSeparator := '=';

finalization
  FreeAndNil(GPassByEmail);
  FreeAndNil(GNameByEmail);

end.
  
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

function NombreDeEmail(const email: String): String;
begin
  if GNameByEmail <> nil then
    Result := GNameByEmail.Values[email]
  else
    Result := '';
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

finalization
  FreeAndNil(GPassByEmail);
  FreeAndNil(GNameByEmail);

end.
