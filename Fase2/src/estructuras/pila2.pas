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

end.
