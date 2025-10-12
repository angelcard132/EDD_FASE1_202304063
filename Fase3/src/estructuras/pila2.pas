unit pila2;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  PCorreo = ^TCorreo;
  TCorreo = record
    id: Integer;
    remitente: String;
    destinatario: String;
    asunto: String;
    mensaje: String;
    siguiente: PCorreo;
  end;

  TPila = record
    tope: PCorreo;
  end;

procedure InicializarPila(var pila: TPila);
procedure Apilar(var pila: TPila; id: Integer; const remitente, destinatario, asunto, mensaje: String);
procedure Desapilar(var pila: TPila);
procedure MostrarPila(var pila: TPila);
function EstaVacia(var pila: TPila): Boolean;
function ContarCorreos(var pila: TPila): Integer;
function BuscarCorreo(var pila: TPila; id: Integer): PCorreo; // ✅ CORREGIR: Agregar parámetro id
procedure LiberarPila(var pila: TPila);

implementation

procedure InicializarPila(var pila: TPila);
begin
  pila.tope := nil;
  WriteLn('🔧 Pila inicializada');
end;

procedure Apilar(var pila: TPila; id: Integer; const remitente, destinatario, asunto, mensaje: String);
var
  nuevo: PCorreo;
begin
  try
    New(nuevo);
    nuevo^.id := id;
    nuevo^.remitente := remitente;
    nuevo^.destinatario := destinatario;
    nuevo^.asunto := asunto;
    nuevo^.mensaje := mensaje;
    nuevo^.siguiente := pila.tope;
    pila.tope := nuevo;
    
    WriteLn('🗑️ Correo apilado - ID: ', id, ' De: ', Copy(remitente, 1, 20), ' Para: ', Copy(destinatario, 1, 20));
  except
    on E: Exception do
    begin
      WriteLn('❌ Error al apilar: ', E.Message);
      if Assigned(nuevo) then
        Dispose(nuevo);
    end;
  end;
end;

procedure Desapilar(var pila: TPila);
var
  temp: PCorreo;
begin
  if pila.tope <> nil then
  begin
    temp := pila.tope;
    pila.tope := pila.tope^.siguiente;
    WriteLn('🗑️ Desapilando ID: ', temp^.id);
    Dispose(temp);
  end;
end;

procedure MostrarPila(var pila: TPila);
var
  actual: PCorreo;
  contador: Integer;
begin
  contador := 0;
  actual := pila.tope;
  WriteLn('📚 Contenido de pila:');
  while (actual <> nil) and (contador < 20) do
  begin
    Inc(contador);
    WriteLn('  ', contador, '. ID: ', actual^.id, ' De: ', actual^.remitente, ' -> ', actual^.destinatario);
    actual := actual^.siguiente;
  end;
  WriteLn('Total: ', contador, ' elementos');
end;

function EstaVacia(var pila: TPila): Boolean;
begin
  EstaVacia := pila.tope = nil;
end;

function ContarCorreos(var pila: TPila): Integer;
var
  actual: PCorreo;
  contador: Integer;
begin
  Result := 0;
  contador := 0;
  
  // Validación para evitar crash
  if @pila = nil then
  begin
    WriteLn('⚠️ CRASH EVITADO: pila es nil en ContarCorreos');
    Exit;
  end;
  
  actual := pila.tope;
  while (actual <> nil) and (contador < 1000) do
  begin
    try
      Inc(contador);
      actual := actual^.siguiente;
    except
      on E: Exception do
      begin
        WriteLn('❌ Error contando elementos en posición ', contador, ': ', E.Message);
        Break;
      end;
    end;
  end;
  
  Result := contador;
  WriteLn('📊 Pila contiene ', contador, ' elementos');
end;

function BuscarCorreo(var pila: TPila; id: Integer): PCorreo; // ✅ CORREGIR: Agregar parámetro id
var
  actual: PCorreo;
begin
  Result := nil;
  actual := pila.tope;
  
  while actual <> nil do
  begin
    if actual^.id = id then
    begin
      Result := actual;
      Exit;
    end;
    actual := actual^.siguiente;
  end;
end;

procedure LiberarPila(var pila: TPila);
var
  contador: Integer;
begin
  contador := 0;
  while not EstaVacia(pila) do
  begin
    Inc(contador);
    Desapilar(pila);
  end;
  WriteLn('🧹 Pila liberada - ', contador, ' elementos');
end;

end.
