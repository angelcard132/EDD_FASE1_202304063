unit json_loader;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, jsonparser, lista_simple, lista_doble;

procedure CargarUsuariosDesdeJSON(const archivo: String; var lista: TListaUsuarios);
procedure CargarCorreosDesdeJSON(const archivo: String; var lista: TListaCorreos);
procedure CargarCorreosDesdeJSON2(const archivo: String; var lista: TListaCorreos; var usuarios: TListaUsuarios);

implementation

procedure CargarUsuariosDesdeJSON(const archivo: String; var lista: TListaUsuarios);
var
  data: TStringList;
  json: TJSONData;
  arr: TJSONArray;
  obj: TJSONObject;
  i: Integer;
begin
  if not FileExists(archivo) then
  begin
    WriteLn('El archivo JSON no existe: ', archivo);
    Exit;
  end;

  data := TStringList.Create;
  try
    data.LoadFromFile(archivo);
    json := GetJSON(data.Text);
    try
      arr := TJSONArray(json.FindPath('usuarios'));
      if arr <> nil then
      begin
        WriteLn('📂 Cargando usuarios desde formato estándar...');
        for i := 0 to arr.Count - 1 do
        begin
          obj := arr.Objects[i];
          InsertarUsuario(lista,
            obj.Get('id', 0),
            obj.Get('nombre', ''),
            obj.Get('usuario', ''),
            obj.Get('password', ''),    // Fix: password comes before email
            obj.Get('email', ''),       // Fix: email comes after password
            obj.Get('telefono', '')
          );
          WriteLn('  ✅ Usuario cargado: ', obj.Get('email', ''));
        end;
        WriteLn('📊 Total usuarios cargados: ', arr.Count);
      end;
    finally
      json.Free;
    end;
  finally
    data.Free;
  end;
end;

procedure CargarCorreosDesdeJSON(const archivo: String; var lista: TListaCorreos);
var
  data: TStringList;
  json: TJSONData;
  arr: TJSONArray;
  obj: TJSONObject;
  i: Integer;
begin
  if not FileExists(archivo) then
  begin
    WriteLn('El archivo JSON no existe: ', archivo);
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
        WriteLn('📂 Cargando correos desde formato estándar...');
        for i := 0 to arr.Count - 1 do
        begin
          obj := arr.Objects[i];
          InsertarCorreo(lista,
            obj.Get('id', 0),
            obj.Get('remitente', ''),
            obj.Get('destinatario', ''),
            obj.Get('estado', 'NL'),
            obj.Get('programado', 'NO'),
            obj.Get('asunto', ''),
            obj.Get('fecha', ''),
            obj.Get('mensaje', '')  // Use 'mensaje' instead of 'contenido'
          );
          WriteLn('  ✅ Correo cargado: ', obj.Get('asunto', ''));
        end;
        WriteLn('📊 Total correos cargados: ', arr.Count);
      end;
    finally
      json.Free;
    end;
  finally
    data.Free;
  end;
end;

procedure CargarCorreosDesdeJSON2(const archivo: String; var lista: TListaCorreos; var usuarios: TListaUsuarios);
var
  data: TStringList;
  json: TJSONData;
  correosArray: TJSONArray;
  usuarioObj: TJSONObject;
  bandejaArray: TJSONArray;
  correoObj: TJSONObject;
  i, j: Integer;
  usuarioId: Integer;
  usuario: PUsuario;
  estado, destinatario: String;
  totalCorreos: Integer;
begin
  if not FileExists(archivo) then
  begin
    WriteLn('El archivo JSON no existe: ', archivo);
    Exit;
  end;

  data := TStringList.Create;
  totalCorreos := 0;
  try
    data.LoadFromFile(archivo);
    json := GetJSON(data.Text);
    try
      correosArray := TJSONArray(json.FindPath('correos'));
      if correosArray <> nil then
      begin
        WriteLn('📂 Cargando correos desde formato por usuario...');
        for i := 0 to correosArray.Count - 1 do
        begin
          usuarioObj := correosArray.Objects[i];
          usuarioId := usuarioObj.Get('usuario_id', 0);
          
          WriteLn('🔍 Buscando usuario con ID: ', usuarioId);
          
          // Buscar el usuario correspondiente
          usuario := nil;
          if usuarios.primero <> nil then
          begin
            usuario := usuarios.primero;
            while (usuario <> nil) and (usuario^.id <> usuarioId) do
              usuario := usuario^.siguiente;
          end;

          if usuario <> nil then
          begin
            destinatario := usuario^.email;
            WriteLn('  📧 Procesando correos para: ', destinatario, ' (ID: ', usuarioId, ')');
            
            bandejaArray := TJSONArray(usuarioObj.FindPath('bandeja_entrada'));
            if bandejaArray <> nil then
            begin
              WriteLn('    📥 Correos en bandeja: ', bandejaArray.Count);
              for j := 0 to bandejaArray.Count - 1 do
              begin
                correoObj := bandejaArray.Objects[j];
                
                // Convertir estado del nuevo formato al formato interno
                if correoObj.Get('estado', '') = 'leído' then
                  estado := 'L'
                else if correoObj.Get('estado', '') = 'no leído' then
                  estado := 'NL'
                else
                  estado := 'NL';

                InsertarCorreo(lista,
                  correoObj.Get('id', 0),
                  correoObj.Get('remitente', ''),
                  destinatario,  // El destinatario es el usuario actual
                  estado,
                  'NO',  // programado (default to NO)
                  correoObj.Get('asunto', ''),
                  correoObj.Get('fecha', ''),
                  correoObj.Get('mensaje', '')  // En el nuevo formato se llama 'mensaje'
                );
                
                WriteLn('    ✅ Correo: ', correoObj.Get('asunto', ''), ' (', estado, ')');
                Inc(totalCorreos);
              end;
            end
            else
            begin
              WriteLn('    ⚠️ No se encontró bandeja_entrada para usuario ID ', usuarioId);
            end;
          end
          else
          begin
            WriteLn('  ⚠️ Usuario con ID ', usuarioId, ' no encontrado en la lista');
          end;
        end;
        WriteLn('📊 Total correos cargados desde formato por usuario: ', totalCorreos);
      end
      else
      begin
        WriteLn('⚠️ No se encontró el array "correos" en el JSON');
      end;
    finally
      json.Free;
    end;
  finally
    data.Free;
  end;
end;

end.
