unit control_login;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, DateUtils, Classes, fpjson, jsonparser;

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
  GControlLogin: record
    cabeza: PRegistroLogin;
  end;

// Funciones públicas
procedure InicializarControlLogin();
procedure RegistrarEntrada(const emailUsuario: String);
procedure RegistrarSalida(const emailUsuario: String);
procedure ExportarLoginJSON(const rutaArchivo: String);
function ObtenerRegistrosLogin(): PRegistroLogin;
procedure LiberarControlLogin();

implementation

procedure InicializarControlLogin();
begin
  GControlLogin.cabeza := nil;
  WriteLn('🔐 Control de login inicializado');
end;

procedure RegistrarEntrada(const emailUsuario: String);
var
  nuevo: PRegistroLogin;
  fechaActual: TDateTime;
begin
  fechaActual := Now;
  
  New(nuevo);
  nuevo^.usuario := emailUsuario;
  nuevo^.fechaEntrada := fechaActual;
  nuevo^.fechaSalida := 0;
  nuevo^.activo := True;
  nuevo^.siguiente := GControlLogin.cabeza;
  GControlLogin.cabeza := nuevo;
  
  WriteLn('🔑 LOGIN registrado: ', emailUsuario, ' - ', FormatDateTime('yyyy-mm-dd hh:nn:ss', fechaActual));
end;

procedure RegistrarSalida(const emailUsuario: String);
var
  actual: PRegistroLogin;
  fechaActual: TDateTime;
begin
  fechaActual := Now;
  actual := GControlLogin.cabeza;
  
  while actual <> nil do
  begin
    if (actual^.usuario = emailUsuario) and actual^.activo then
    begin
      actual^.fechaSalida := fechaActual;
      actual^.activo := False;
      WriteLn('🔐 LOGOUT registrado: ', emailUsuario, ' - ', FormatDateTime('yyyy-mm-dd hh:nn:ss', fechaActual));
      Exit;
    end;
    actual := actual^.siguiente;
  end;
  
  WriteLn('⚠️ No se encontró sesión activa para: ', emailUsuario);
end;

function ObtenerRegistrosLogin(): PRegistroLogin;
begin
  Result := GControlLogin.cabeza;
end;

procedure ExportarLoginJSON(const rutaArchivo: String);
var
  jsonArray: TJSONArray;
  jsonObj: TJSONObject;
  actual: PRegistroLogin;
  archivoTexto: TStringList;
  fechaEntrada, fechaSalida: String;
begin
  jsonArray := TJSONArray.Create;
  archivoTexto := TStringList.Create;
  
  try
    actual := GControlLogin.cabeza;
    
    while actual <> nil do
    begin
      if not actual^.activo and (actual^.fechaSalida > 0) then
      begin
        jsonObj := TJSONObject.Create;
        
        fechaEntrada := FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', actual^.fechaEntrada);
        fechaSalida := FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', actual^.fechaSalida);
        
        jsonObj.Add('usuario', actual^.usuario);
        jsonObj.Add('entrada', fechaEntrada);
        jsonObj.Add('salida', fechaSalida);
        
        jsonArray.Add(jsonObj);
      end;
      
      actual := actual^.siguiente;
    end;
    
    archivoTexto.Text := jsonArray.FormatJSON();
    archivoTexto.SaveToFile(rutaArchivo);
    
    WriteLn('📄 JSON de control de login exportado: ', rutaArchivo);
    WriteLn('📊 Total de registros exportados: ', jsonArray.Count);
    
  finally
    jsonArray.Free;
    archivoTexto.Free;
  end;
end;

procedure LiberarControlLogin();
var
  actual, temp: PRegistroLogin;
begin
  actual := GControlLogin.cabeza;
  while actual <> nil do
  begin
    temp := actual^.siguiente;
    Dispose(actual);
    actual := temp;
  end;
  GControlLogin.cabeza := nil;
  WriteLn('🧹 Control de login liberado');
end;

initialization
  InicializarControlLogin();

finalization
  LiberarControlLogin();

end.
