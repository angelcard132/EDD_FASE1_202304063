unit lista_doble;

{$mode objfpc}{$H+}

interface

type
  PCorreo = ^TCorreo;
  TCorreo = record
    id: Integer;
    remitente: String;
    destinatario: String;   // 🔹 nuevo campo
    estado: String;
    asunto: String;
    fecha: String;
    contenido: String;
    siguiente: PCorreo;
  end;

  TListaCorreos = record
    primero: PCorreo;
    ultimo: PCorreo;
  end;

procedure InicializarListaCorreos(var lista: TListaCorreos);
procedure InsertarCorreo(var lista: TListaCorreos; id: Integer; remitente, destinatario, estado, asunto, fecha, contenido: String);
procedure MostrarCorreos(const lista: TListaCorreos);

implementation

procedure InicializarListaCorreos(var lista: TListaCorreos);
begin
  lista.primero := nil;
  lista.ultimo := nil;
end;

procedure InsertarCorreo(var lista: TListaCorreos; id: Integer; remitente, destinatario, estado, asunto, fecha, contenido: String);
var
  nuevo: PCorreo;
begin
  New(nuevo);
  nuevo^.id := id;
  nuevo^.remitente := remitente;
  nuevo^.destinatario := destinatario;  // 🔹 guardar destinatario
  nuevo^.estado := estado;
  nuevo^.asunto := asunto;
  nuevo^.fecha := fecha;
  nuevo^.contenido := contenido;
  nuevo^.siguiente := nil;

  if lista.primero = nil then
  begin
    lista.primero := nuevo;
    lista.ultimo := nuevo;
  end
  else
  begin
    lista.ultimo^.siguiente := nuevo;
    lista.ultimo := nuevo;
  end;
end;

procedure MostrarCorreos(const lista: TListaCorreos);
var
  aux: PCorreo;
begin
  aux := lista.primero;
  while aux <> nil do
  begin
    WriteLn('ID: ', aux^.id, ' | De: ', aux^.remitente, ' | Para: ', aux^.destinatario,
            ' | Asunto: ', aux^.asunto, ' | Estado: ', aux^.estado);
    aux := aux^.siguiente;
  end;
end;

end.
