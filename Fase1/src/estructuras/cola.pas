unit cola;

{$mode objfpc}{$H+}

interface

type
  PCorreoCola = ^TCorreoCola;
  TCorreoCola = record
    id: Integer;
    remitente: String;
    destinatario: String;
    asunto: String;
    fecha: String;   // fecha programada
    mensaje: String;
    siguiente: PCorreoCola;
  end;

  TCola = record
    frente, final: PCorreoCola;
  end;

procedure InicializarCola(var cola: TCola);
procedure Encolar(var cola: TCola; id: Integer; remitente, destinatario, asunto, fecha, mensaje: String);
function Desencolar(var cola: TCola): PCorreoCola;
procedure MostrarCola(cola: TCola);

implementation

procedure InicializarCola(var cola: TCola);
begin
  cola.frente := nil;
  cola.final := nil;
end;

procedure Encolar(var cola: TCola; id: Integer; remitente, destinatario, asunto, fecha, mensaje: String);
var
  nuevo: PCorreoCola;
begin
  New(nuevo);
  nuevo^.id := id;
  nuevo^.remitente := remitente;
  nuevo^.destinatario := destinatario;
  nuevo^.asunto := asunto;
  nuevo^.fecha := fecha;
  nuevo^.mensaje := mensaje;
  nuevo^.siguiente := nil;

  if cola.frente = nil then
    cola.frente := nuevo
  else
    cola.final^.siguiente := nuevo;

  cola.final := nuevo;
end;

function Desencolar(var cola: TCola): PCorreoCola;
var
  aux: PCorreoCola;
begin
  if cola.frente = nil then
    Exit(nil);

  aux := cola.frente;
  cola.frente := cola.frente^.siguiente;

  if cola.frente = nil then
    cola.final := nil;

  Desencolar := aux;
end;

procedure MostrarCola(cola: TCola);
var
  aux: PCorreoCola;
begin
  aux := cola.frente;
  if aux = nil then
  begin
    WriteLn('La cola de correos programados está vacía');
    Exit;
  end;

  while aux <> nil do
  begin
    WriteLn('ID: ', aux^.id, ' | De: ', aux^.remitente, ' | Para: ', aux^.destinatario, ' | Asunto: ', aux^.asunto, ' | Fecha: ', aux^.fecha);
    aux := aux^.siguiente;
  end;
end;

end.
