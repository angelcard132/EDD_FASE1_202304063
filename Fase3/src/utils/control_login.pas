unit control_login;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpjson, jsonparser;

type
  PRegistroLogin = ^TRegistroLogin;
  TRegistroLogin = record
    usuario: String;
    fechaEntrada: TDateTime;
    fechaSalida: TDateTime;
    activo: Boolean;
    siguiente: PRegistroLogin;
  end;

var
  RegistrosLogin: PRegistroLogin = nil;

// Funciones principales
procedure RegistrarEntrada(const usuario: String);
procedure RegistrarSalida(const usuario: String);
function ObtenerRegistrosLogin(): PRegistroLogin;
procedure ExportarLoginJSON(const rutaArchivo: String);
procedure LiberarControlLogin();

implementation

procedure RegistrarEntrada(const usuario: String);
var
  nuevo: PRegistroLogin;
begin
  New(nuevo);
  nuevo^.usuario := usuario;
  nuevo^.fechaEntrada := Now;
  nuevo^.fechaSalida := 0;
  nuevo^.activo := True;
  nuevo^.siguiente := RegistrosLogin;
  RegistrosLogin := nuevo;
  
  WriteLn('🔐 Entrada registrada: ', usuario, ' a las ', FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
end;

procedure RegistrarSalida(const usuario: String);
var
  actual: PRegistroLogin;
begin
  actual := RegistrosLogin;
  while actual <> nil do
  begin
    if (actual^.usuario = usuario) and actual^.activo then
    begin
      actual^.fechaSalida := Now;
      actual^.activo := False;
      WriteLn('🔐 Salida registrada: ', usuario, ' a las ', FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
      Exit;
    end;
    actual := actual^.siguiente;
  end;
  
  WriteLn('⚠️ No se encontró entrada activa para: ', usuario);
end;

function ObtenerRegistrosLogin(): PRegistroLogin;
begin
  Result := RegistrosLogin;
end;

procedure ExportarLoginJSON(const rutaArchivo: String);
var
  jsonArray: TJSONArray;
  jsonObj: TJSONObject;
  actual: PRegistroLogin;
  archivo: TStringList;
begin
  jsonArray := TJSONArray.Create;
  archivo := TStringList.Create;
  
  try
    actual := RegistrosLogin;
    while actual <> nil do
    begin
      jsonObj := TJSONObject.Create;
      jsonObj.Add('usuario', actual^.usuario);
      jsonObj.Add('fechaEntrada', FormatDateTime('yyyy-mm-dd hh:nn:ss', actual^.fechaEntrada));
      
      if actual^.fechaSalida > 0 then
        jsonObj.Add('fechaSalida', FormatDateTime('yyyy-mm-dd hh:nn:ss', actual^.fechaSalida))
      else
        jsonObj.Add('fechaSalida', 'null');
        
      jsonObj.Add('activo', actual^.activo);
      
      jsonArray.Add(jsonObj);
      actual := actual^.siguiente;
    end;
    
    archivo.Text := jsonArray.FormatJSON;
    archivo.SaveToFile(rutaArchivo);
    WriteLn('📄 Control de login exportado a: ', rutaArchivo);
    
  finally
    jsonArray.Free;
    archivo.Free;
  end;
end;

procedure LiberarControlLogin();
var
  actual, temp: PRegistroLogin;
begin
  actual := RegistrosLogin;
  while actual <> nil do
  begin
    temp := actual^.siguiente;
    Dispose(actual);
    actual := temp;
  end;
  RegistrosLogin := nil;
end;

end.
