unit lzw_compression;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes;

// Funciones principales de compresión LZW
function ComprimirLZW(const texto: String): String;
function DescomprimirLZW(const datosComprimidos: String): String;

// Funciones auxiliares para conversión
function StringToBytes(const s: String): TBytes;
function BytesToString(const bytes: TBytes): String;

implementation

type
  TDiccionario = record
    claves: array of String;
    valores: array of Integer;
    count: Integer;
  end;

procedure InicializarDiccionario(var dict: TDiccionario; estaComprimiendo: Boolean);
var
  i: Integer;
begin
  SetLength(dict.claves, 4096);
  SetLength(dict.valores, 4096);
  dict.count := 0;
  
  // Inicializar con caracteres ASCII básicos (0-255)
  for i := 0 to 255 do
  begin
    dict.claves[i] := Chr(i);
    dict.valores[i] := i;
    Inc(dict.count);
  end;
end;

function BuscarEnDiccionario(const dict: TDiccionario; const clave: String): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to dict.count - 1 do
  begin
    if dict.claves[i] = clave then
    begin
      Result := dict.valores[i];
      Exit;
    end;
  end;
end;

function BuscarCodigoDiccionario(const dict: TDiccionario; codigo: Integer): String;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to dict.count - 1 do
  begin
    if dict.valores[i] = codigo then
    begin
      Result := dict.claves[i];
      Exit;
    end;
  end;
end;

procedure AgregarADiccionario(var dict: TDiccionario; const clave: String; valor: Integer);
begin
  if dict.count < Length(dict.claves) then
  begin
    dict.claves[dict.count] := clave;
    dict.valores[dict.count] := valor;
    Inc(dict.count);
  end;
end;

function ComprimirLZW(const texto: String): String;
var
  dict: TDiccionario;
  i: Integer;
  secuenciaActual: String;
  resultado: TStringList;
  codigo: Integer;
  siguienteCodigo: Integer;
begin
  if Length(texto) = 0 then
  begin
    Result := '';
    Exit;
  end;
  
  InicializarDiccionario(dict, True);
  resultado := TStringList.Create;
  
  try
    secuenciaActual := texto[1];
    siguienteCodigo := 256;
    
    for i := 2 to Length(texto) do
    begin
      secuenciaActual := secuenciaActual + texto[i];
      
      // Si la secuencia actual existe en el diccionario, continuar
      if BuscarEnDiccionario(dict, secuenciaActual) <> -1 then
        Continue;
      
      // La secuencia no existe, agregar al diccionario
      AgregarADiccionario(dict, secuenciaActual, siguienteCodigo);
      Inc(siguienteCodigo);
      
      // Obtener código de la secuencia sin el último carácter
      secuenciaActual := Copy(secuenciaActual, 1, Length(secuenciaActual) - 1);
      codigo := BuscarEnDiccionario(dict, secuenciaActual);
      resultado.Add(IntToStr(codigo));
      
      // Comenzar nueva secuencia con el carácter actual
      secuenciaActual := texto[i];
    end;
    
    // Agregar el último código
    codigo := BuscarEnDiccionario(dict, secuenciaActual);
    if codigo <> -1 then
      resultado.Add(IntToStr(codigo));
    
    // Convertir lista de códigos a string separado por comas
    Result := '';
    for i := 0 to resultado.Count - 1 do
    begin
      if i > 0 then
        Result := Result + ',';
      Result := Result + resultado[i];
    end;
    
  finally
    resultado.Free;
  end;
end;

function DescomprimirLZW(const datosComprimidos: String): String;
var
  dict: TDiccionario;
  codigos: TStringList;
  resultado: String;
  i, codigo, codigoAnterior: Integer;
  cadena, cadenaAnterior: String;
  siguienteCodigo: Integer;
begin
  if Length(datosComprimidos) = 0 then
  begin
    Result := '';
    Exit;
  end;
  
  InicializarDiccionario(dict, False);
  codigos := TStringList.Create;
  
  try
    // Separar códigos por comas
    codigos.CommaText := datosComprimidos;
    
    if codigos.Count = 0 then
    begin
      Result := '';
      Exit;
    end;
    
    resultado := '';
    siguienteCodigo := 256;
    
    // Procesar primer código
    codigoAnterior := StrToIntDef(codigos[0], 0);
    cadenaAnterior := BuscarCodigoDiccionario(dict, codigoAnterior);
    resultado := cadenaAnterior;
    
    // Procesar códigos restantes
    for i := 1 to codigos.Count - 1 do
    begin
      codigo := StrToIntDef(codigos[i], 0);
      cadena := BuscarCodigoDiccionario(dict, codigo);
      
      // Si el código no existe en el diccionario (caso especial)
      if cadena = '' then
        cadena := cadenaAnterior + cadenaAnterior[1];
      
      resultado := resultado + cadena;
      
      // Agregar nueva entrada al diccionario
      AgregarADiccionario(dict, cadenaAnterior + cadena[1], siguienteCodigo);
      Inc(siguienteCodigo);
      
      cadenaAnterior := cadena;
    end;
    
    Result := resultado;
    
  finally
    codigos.Free;
  end;
end;

function StringToBytes(const s: String): TBytes;
var
  i: Integer;
begin
  SetLength(Result, Length(s));
  for i := 0 to Length(s) - 1 do
    Result[i] := Ord(s[i + 1]);
end;

function BytesToString(const bytes: TBytes): String;
var
  i: Integer;
begin
  SetLength(Result, Length(bytes));
  for i := 0 to Length(bytes) - 1 do
    Result[i + 1] := Chr(bytes[i]);
end;

end.
