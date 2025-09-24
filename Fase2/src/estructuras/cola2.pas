unit cola2;

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

  TCola = record
    frente, final: PCorreo;
  end;

procedure InicializarCola(var cola: TCola);
procedure Encolar(var cola: TCola; id: Integer; remitente, destinatario, asunto, mensaje: String);
procedure Desencolar(var cola: TCola);
procedure MostrarCola(var cola: TCola);

implementation

procedure InicializarCola(var cola: TCola);
begin
  cola.frente := nil;
  cola.final := nil;
end;

procedure Encolar(var cola: TCola; id: Integer; remitente, destinatario, asunto, mensaje: String);
var
  nuevo: PCorreo;
begin
  New(nuevo);
  nuevo^.id := id;
  nuevo^.remitente := remitente;
  nuevo^.destinatario := destinatario;
  nuevo^.asunto := asunto;
  nuevo^.mensaje := mensaje;
  nuevo^.siguiente := nil;

  if cola.frente = nil then
  begin
    cola.frente := nuevo;
    cola.final := nuevo;
  end
  else
  begin
    cola.final^.siguiente := nuevo;
    cola.final := nuevo;
  end;
end;

procedure Desencolar(var cola: TCola);
var
  temp: PCorreo;
begin
  if cola.frente <> nil then
  begin
    temp := cola.frente;
    cola.frente := cola.frente^.siguiente;
    Dispose(temp);
    if cola.frente = nil then
      cola.final := nil;
  end
  else
    WriteLn('La cola está vacía.');
end;

procedure MostrarCola(var cola: TCola);
var
  actual: PCorreo;
begin
  actual := cola.frente;
  while actual <> nil do
  begin
    WriteLn('ID: ', actual^.id, ' | De: ', actual^.remitente, ' -> ', actual^.destinatario,
            ' | Asunto: ', actual^.asunto, ' | Mensaje: ', actual^.mensaje);
    actual := actual^.siguiente;
  end;
end;

end.
