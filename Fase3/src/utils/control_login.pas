unit control_login;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes;

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

{ Funciones principales }
procedure InicializarControlLogin();
procedure RegistrarEntrada(const usuario: String);
procedure RegistrarSalida(const usuario: String);
function ObtenerRegistrosLogin(): PRegistroLogin;
procedure ExportarLoginJSON(const rutaArchivo: String);
procedure LiberarControlLogin();

implementation

uses
  fpjson, jsonparser;

procedure InicializarControlLogin();
begin
  RegistrosLogin := nil;
  WriteLn('🔐 Control de login inicializado');
end;

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
  
  WriteLn('🔐 LOGIN registrado: ', usuario, ' en ', FormatDateTime('dd/mm/yyyy hh:nn:ss', Now));
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
      WriteLn('🔐 LOGOUT registrado: ', usuario, ' en ', FormatDateTime('dd/mm/yyyy hh:nn:ss', Now));
      Exit;
    end;
    actual := actual^.siguiente;
  end;
  
  WriteLn('⚠️ No se encontró sesión activa para: ', usuario);
end;

function ObtenerRegistrosLogin(): PRegistroLogin;
begin
  Result := RegistrosLogin;
end;

procedure ExportarLoginJSON(const rutaArchivo: String);
var
  jsonObj, registroObj: TJSONObject;
  jsonArray: TJSONArray;
  actual: PRegistroLogin;
  archivo: TextFile;
begin
  jsonObj := TJSONObject.Create;
  jsonArray := TJSONArray.Create;
  
  try
    actual := RegistrosLogin;
    while actual <> nil do
    begin
      registroObj := TJSONObject.Create;
      registroObj.Add('usuario', actual^.usuario);
      registroObj.Add('fechaEntrada', FormatDateTime('dd/mm/yyyy hh:nn:ss', actual^.fechaEntrada));
      
      if actual^.fechaSalida > 0 then
        registroObj.Add('fechaSalida', FormatDateTime('dd/mm/yyyy hh:nn:ss', actual^.fechaSalida))
      else
        registroObj.Add('fechaSalida', 'ACTIVO');
        
      registroObj.Add('activo', actual^.activo);
      jsonArray.Add(registroObj);
      actual := actual^.siguiente;
    end;
    
    jsonObj.Add('registros', jsonArray);
    jsonObj.Add('totalRegistros', jsonArray.Count);
    jsonObj.Add('fechaExportacion', FormatDateTime('dd/mm/yyyy hh:nn:ss', Now));
    
    AssignFile(archivo, rutaArchivo);
    Rewrite(archivo);
    WriteLn(archivo, jsonObj.AsJSON);
    CloseFile(archivo);
    
    WriteLn('📄 Control de login exportado a: ', rutaArchivo);
    
  finally
    jsonObj.Free;
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

initialization
  InicializarControlLogin();

finalization
  LiberarControlLogin();

end.
