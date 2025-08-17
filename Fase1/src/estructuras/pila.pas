unit pila;

{$mode objfpc}{$H+}

interface

type
  PCorreoPila = ^TCorreoPila;
  TCorreoPila = record
    id: Integer;
    remitente: String;
    asunto: String;
    fecha: String;
    mensaje: String;
    siguiente: PCorreoPila;
  end;

  TPila = record
    tope: PCorreoPila;
  end;

procedure InicializarPila(var pila: TPila);
procedure Push(var pila: TPila; id: Integer; remitente, asunto, fecha, mensaje: String);
function Pop(var pila: TPila): PCorreoPila;
procedure MostrarPila(pila: TPila);
function BuscarEnPapelera(pila: TPila; clave: String): PCorreoPila;

implementation

procedure InicializarPila(var pila: TPila);
begin
  pila.tope := nil;
end;

procedure Push(var pila: TPila; id: Integer; remitente, asunto, fecha, mensaje: String);
var
  nuevo: PCorreoPila;
begin
  New(nuevo);
  nuevo^.id := id;
  nuevo^.remitente := remitente;
  nuevo^.asunto := asunto;
  nuevo^.fecha := fecha;
  nuevo^.mensaje := mensaje;
  nuevo^.siguiente := pila.tope;
  pila.tope := nuevo;
end;

function Pop(var pila: TPila): PCorreoPila;
var
  aux: PCorreoPila;
begin
  if pila.tope = nil then
    Exit(nil);

  aux := pila.tope;
  pila.tope := pila.tope^.siguiente;
  Pop := aux;
end;

procedure MostrarPila(pila: TPila);
var
  aux: PCorreoPila;
begin
  aux := pila.tope;
  if aux = nil then
  begin
    WriteLn('La papelera está vacía');
    Exit;
  end;

  while aux <> nil do
  begin
    WriteLn('ID: ', aux^.id, ' | De: ', aux^.remitente, ' | Asunto: ', aux^.asunto, ' | Fecha: ', aux^.fecha);
    aux := aux^.siguiente;
  end;
end;

function BuscarEnPapelera(pila: TPila; clave: String): PCorreoPila;
var
  aux: PCorreoPila;
begin
  BuscarEnPapelera := nil;
  aux := pila.tope;
  while aux <> nil do
  begin
    if Pos(LowerCase(clave), LowerCase(aux^.asunto)) > 0 then
    begin
      BuscarEnPapelera := aux;
      Exit;
    end;
    aux := aux^.siguiente;
  end;
end;

end.
