unit lista_doble;

{$mode objfpc}{$H+}

interface

type
  PCorreo = ^TCorreo;
  TCorreo = record
    id: Integer;
    remitente: String;
    estado: String;       // 'NL' = No leído, 'L' = Leído
    programado: Boolean;  // True si estaba en cola programada
    asunto: String;
    fecha: String;
    mensaje: String;
    anterior: PCorreo;
    siguiente: PCorreo;
  end;

  TListaCorreos = record
    primero, ultimo: PCorreo;
  end;

procedure InicializarListaCorreos(var lista: TListaCorreos);
procedure InsertarCorreo(var lista: TListaCorreos; id: Integer; remitente, estado, asunto, fecha, mensaje: String; programado: Boolean);
procedure MostrarCorreos(lista: TListaCorreos);
function BuscarCorreoPorAsunto(lista: TListaCorreos; clave: String): PCorreo;
procedure MarcarComoLeido(correo: PCorreo);
procedure EliminarCorreo(var lista: TListaCorreos; id: Integer);

// 🔹 Nuevas funciones para bandeja de entrada
function ContarNoLeidos(lista: TListaCorreos): Integer;
procedure OrdenarCorreosPorAsunto(var lista: TListaCorreos);

implementation

procedure InicializarListaCorreos(var lista: TListaCorreos);
begin
  lista.primero := nil;
  lista.ultimo := nil;
end;

procedure InsertarCorreo(var lista: TListaCorreos; id: Integer; remitente, estado, asunto, fecha, mensaje: String; programado: Boolean);
var
  nuevo: PCorreo;
begin
  New(nuevo);
  nuevo^.id := id;
  nuevo^.remitente := remitente;
  nuevo^.estado := estado;
  nuevo^.programado := programado;
  nuevo^.asunto := asunto;
  nuevo^.fecha := fecha;
  nuevo^.mensaje := mensaje;
  nuevo^.siguiente := nil;
  nuevo^.anterior := lista.ultimo;

  if lista.primero = nil then
    lista.primero := nuevo
  else
    lista.ultimo^.siguiente := nuevo;

  lista.ultimo := nuevo;
end;

procedure MostrarCorreos(lista: TListaCorreos);
var
  aux: PCorreo;
begin
  aux := lista.primero;
  while aux <> nil do
  begin
    WriteLn('ID: ', aux^.id,
            ' | Estado: ', aux^.estado,
            ' | Asunto: ', aux^.asunto,
            ' | De: ', aux^.remitente,
            ' | Fecha: ', aux^.fecha);
    aux := aux^.siguiente;
  end;
end;

function BuscarCorreoPorAsunto(lista: TListaCorreos; clave: String): PCorreo;
var
  aux: PCorreo;
begin
  aux := lista.primero;
  while (aux <> nil) and (Pos(LowerCase(clave), LowerCase(aux^.asunto)) = 0) do
    aux := aux^.siguiente;
  BuscarCorreoPorAsunto := aux;
end;

procedure MarcarComoLeido(correo: PCorreo);
begin
  if correo <> nil then
    correo^.estado := 'L';
end;

procedure EliminarCorreo(var lista: TListaCorreos; id: Integer);
var
  aux: PCorreo;
begin
  aux := lista.primero;
  while (aux <> nil) and (aux^.id <> id) do
    aux := aux^.siguiente;

  if aux <> nil then
  begin
    if aux^.anterior <> nil then
      aux^.anterior^.siguiente := aux^.siguiente
    else
      lista.primero := aux^.siguiente;

    if aux^.siguiente <> nil then
      aux^.siguiente^.anterior := aux^.anterior
    else
      lista.ultimo := aux^.anterior;

    Dispose(aux);
  end;
end;

function ContarNoLeidos(lista: TListaCorreos): Integer;
var
  aux: PCorreo;
  contador: Integer;
begin
  contador := 0;
  aux := lista.primero;
  while aux <> nil do
  begin
    if aux^.estado = 'NL' then
      Inc(contador);
    aux := aux^.siguiente;
  end;
  ContarNoLeidos := contador;
end;

procedure OrdenarCorreosPorAsunto(var lista: TListaCorreos);
var
  cambiado: Boolean;
  aux: PCorreo;
  temp: TCorreo;
begin
  if (lista.primero = nil) or (lista.primero^.siguiente = nil) then Exit;

  repeat
    cambiado := False;
    aux := lista.primero;
    while aux^.siguiente <> nil do
    begin
      if LowerCase(aux^.asunto) > LowerCase(aux^.siguiente^.asunto) then
      begin
        // Intercambiar datos (swap)
        temp := aux^;
        aux^ := aux^.siguiente^;
        aux^.siguiente^ := temp;
        cambiado := True;
      end;
      aux := aux^.siguiente;
    end;
  until not cambiado;
end;

end.
