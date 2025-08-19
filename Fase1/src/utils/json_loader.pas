unit json_loader;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, jsonparser, lista_simple, lista_doble;

procedure CargarUsuariosDesdeJSON(const ruta: string; var lista: TListaUsuarios);
procedure CargarCorreosDesdeJSON(const ruta: string; var lista: TListaCorreos);

implementation

procedure CargarUsuariosDesdeJSON(const ruta: string; var lista: TListaUsuarios);
var
  data: TJSONData;
  arr: TJSONArray;
  obj: TJSONObject;
  parser: TJSONParser;
  i: Integer;
  archivo: TStringStream;
  pass: String;
begin
  if not FileExists(ruta) then
  begin
    WriteLn('El archivo JSON no existe: ', ruta);
    Exit;
  end;

  archivo := TStringStream.Create('');
  try
    archivo.LoadFromFile(ruta);
    parser := TJSONParser.Create(archivo.DataString);
    try
      data := parser.Parse;
      arr := data.FindPath('usuarios') as TJSONArray;
      if arr = nil then Exit;

      for i := 0 to arr.Count - 1 do
      begin
        obj := arr.Objects[i];
        pass := obj.Get('password', '1234'); // 🔹 por si no viene en el JSON
        InsertarUsuario(
          lista,
          obj.Get('id', 0),
          obj.Get('nombre', ''),
          obj.Get('usuario', ''),
          obj.Get('email', ''),
          obj.Get('telefono', ''),
          pass
        );
      end;
    finally
      parser.Free;
      data.Free;
    end;
  finally
    archivo.Free;
  end;
end;

procedure CargarCorreosDesdeJSON(const ruta: string; var lista: TListaCorreos);
var
  data: TJSONData;
  arr: TJSONArray;
  obj: TJSONObject;
  parser: TJSONParser;
  i: Integer;
  archivo: TStringStream;
begin
  if not FileExists(ruta) then
  begin
    WriteLn('El archivo JSON no existe: ', ruta);
    Exit;
  end;

  archivo := TStringStream.Create('');
  try
    archivo.LoadFromFile(ruta);
    parser := TJSONParser.Create(archivo.DataString);
    try
      data := parser.Parse;
      arr := data.FindPath('correos') as TJSONArray;
      if arr = nil then Exit;

      for i := 0 to arr.Count - 1 do
      begin
        obj := arr.Objects[i];
        InsertarCorreo(
          lista,
          obj.Get('id', 0),
          obj.Get('remitente', ''),
          obj.Get('estado', 'NL'),
          obj.Get('asunto', ''),
          obj.Get('fecha', ''),
          obj.Get('contenido', ''),
          False
        );
      end;
    finally
      parser.Free;
      data.Free;
    end;
  finally
    archivo.Free;
  end;
end;

end.
