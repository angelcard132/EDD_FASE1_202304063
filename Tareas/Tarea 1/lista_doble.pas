unit lista_doble;

{$mode objfpc}{$H+}

interface

type
  PCorreo = ^TCorreo;
  TCorreo = record
    id: Integer;
    remitente: String;
    destinatario: String;  // Add destinatario field for proper filtering
    estado: String;
    programado: String;
    asunto: String;
    fecha: String;
    mensaje: String;
    anterior: PCorreo;
    siguiente: PCorreo;
  end;

  TListaCorreos = record
    primero: PCorreo;
    ultimo: PCorreo;
  end;

procedure InicializarListaCorreos(var lista: TListaCorreos);
procedure InsertarCorreo(var lista: TListaCorreos; id: Integer; remitente, destinatario, estado, programado, asunto, fecha, mensaje: String);
procedure MostrarCorreos(const lista: TListaCorreos; const emailUsuario: String);

implementation

procedure InicializarListaCorreos(var lista: TListaCorreos);
begin
  lista.primero := nil;
  lista.ultimo := nil;
end;

procedure InsertarCorreo(var lista: TListaCorreos; id: Integer; remitente, destinatario, estado, programado, asunto, fecha, mensaje: String);
var
  nuevo: PCorreo;
begin
  New(nuevo);
  nuevo^.id := id;
  nuevo^.remitente := remitente;
  nuevo^.destinatario := destinatario;
  nuevo^.estado := estado;
  nuevo^.programado := programado;
  nuevo^.asunto := asunto;
  nuevo^.fecha := fecha;
  nuevo^.mensaje := mensaje;
  nuevo^.anterior := nil;
  nuevo^.siguiente := nil;

  if lista.primero = nil then
  begin
    lista.primero := nuevo;
    lista.ultimo := nuevo;
  end
  else
  begin
    lista.ultimo^.siguiente := nuevo;
    nuevo^.anterior := lista.ultimo;
    lista.ultimo := nuevo;
  end;
end;

procedure MostrarCorreos(const lista: TListaCorreos; const emailUsuario: String);
var
  aux: PCorreo;
begin
  WriteLn('=== Correos para: ', emailUsuario, ' ===');
  aux := lista.primero;
  while aux <> nil do
  begin
    if LowerCase(aux^.destinatario) = LowerCase(emailUsuario) then
      WriteLn('ID: ', aux^.id, ' | De: ', aux^.remitente, ' | Asunto: ', aux^.asunto, 
              ' | Estado: ', aux^.estado, ' | Fecha: ', aux^.fecha);
    aux := aux^.siguiente;
  end;
end;

end.
