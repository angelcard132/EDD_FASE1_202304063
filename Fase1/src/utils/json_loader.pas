unit json_loader;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, jsonparser, lista_simple;

procedure CargarUsuariosDesdeJSON(ruta: String; var lista: TListaUsuarios);

implementation

procedure CargarUsuariosDesdeJSON(ruta: String; var lista: TListaUsuarios);
var
  archivo: TFileStream;
  jsonData: TJSONData;
  usuariosArray: TJSONArray;
  usuarioObj: TJSONObject;
  i, id: Integer;
  nombre, usuario, email, telefono: String;
begin
  if not FileExists(ruta) then
  begin
    WriteLn('El archivo JSON no existe: ', ruta);
    Exit;
  end;

  archivo := TFileStream.Create(ruta, fmOpenRead);
  try
    jsonData := GetJSON(archivo);
    try
      usuariosArray := jsonData.FindPath('usuarios') as TJSONArray;
      for i := 0 to usuariosArray.Count - 1 do
      begin
        usuarioObj := usuariosArray.Objects[i];
        id := usuarioObj.Get('id', 0);
        nombre := usuarioObj.Get('nombre', '');
        usuario := usuarioObj.Get('usuario', '');
        email := usuarioObj.Get('email', '');
        telefono := usuarioObj.Get('telefono', '');
        InsertarUsuario(lista, id, nombre, usuario, email, telefono);
      end;
    finally
      jsonData.Free;
    end;
  finally
    archivo.Free;
  end;
end;

end.
