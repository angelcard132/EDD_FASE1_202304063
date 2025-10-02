unit pila2;

interface

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
procedure Apilar(var pila: TPila; id: Integer; remitente, destinatario, asunto, mensaje: String);
procedure Desapilar(var pila: TPila);
procedure MostrarPila(var pila: TPila);
function EstaVacia(var pila: TPila): Boolean;
function ContarCorreos(var pila: TPila): Integer;
function BuscarCorreo(var pila: TPila; id: Integer): PCorreo;
procedure LiberarPila(var pila: TPila);

implementation

procedure InicializarPila(var pila: TPila);
begin
  pila.tope := nil;
end;

procedure Apilar(var pila: TPila; id: Integer; remitente, destinatario, asunto, mensaje: String);
var
  nuevo: PCorreo;
begin
  New(nuevo);
  nuevo^.id := id;
  nuevo^.remitente := remitente;
  nuevo^.destinatario := destinatario;
  nuevo^.asunto := asunto;
  nuevo^.mensaje := mensaje;
  nuevo^.siguiente := pila.tope;
  pila.tope := nuevo;
end;

procedure Desapilar(var pila: TPila);
var
  temp: PCorreo;
begin
  if pila.tope <> nil then
  begin
    temp := pila.tope;
    pila.tope := pila.tope^.siguiente;
    Dispose(temp);
  end
  else
    WriteLn('La pila está vacía.');
end;

procedure MostrarPila(var pila: TPila);
var
  actual: PCorreo;
begin
  actual := pila.tope;
  while actual <> nil do
  begin
    WriteLn('ID: ', actual^.id, ' | De: ', actual^.remitente, ' -> ', actual^.destinatario,
            ' | Asunto: ', actual^.asunto, ' | Mensaje: ', actual^.mensaje);
    actual := actual^.siguiente;
  end;
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
  contador := 0;
  actual := pila.tope;
  while actual <> nil do
  begin
    Inc(contador);
    actual := actual^.siguiente;
  end;
  ContarCorreos := contador;
end;

function BuscarCorreo(var pila: TPila; id: Integer): PCorreo;
var
  actual: PCorreo;
begin
  BuscarCorreo := nil;
  actual := pila.tope;
  while actual <> nil do
  begin
    if actual^.id = id then
    begin
      BuscarCorreo := actual;
      Exit;
    end;
    actual := actual^.siguiente;
  end;
end;

procedure LiberarPila(var pila: TPila);
begin
  while not EstaVacia(pila) do
    Desapilar(pila);
end;

end.
