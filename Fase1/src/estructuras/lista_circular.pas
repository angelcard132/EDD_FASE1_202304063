unit lista_circular;

{$mode objfpc}{$H+}

interface

type
  PContacto = ^TContacto;
  TContacto = record
    id: Integer;
    nombre: String;
    email: String;
    siguiente: PContacto;
    anterior: PContacto;
  end;

  TListaContactos = record
    primero: PContacto;
  end;

procedure InicializarContactos(var lista: TListaContactos);
procedure InsertarContacto(var lista: TListaContactos; id: Integer; nombre, email: String);
procedure MostrarContactos(lista: TListaContactos; limite: Integer);
function BuscarContacto(lista: TListaContactos; email: String): PContacto;

implementation

procedure InicializarContactos(var lista: TListaContactos);
begin
  lista.primero := nil;
end;

procedure InsertarContacto(var lista: TListaContactos; id: Integer; nombre, email: String);
var
  nuevo, ultimo: PContacto;
begin
  New(nuevo);
  nuevo^.id := id;
  nuevo^.nombre := nombre;
  nuevo^.email := email;

  if lista.primero = nil then
  begin
    lista.primero := nuevo;
    nuevo^.siguiente := nuevo;
    nuevo^.anterior := nuevo;
  end
  else
  begin
    ultimo := lista.primero^.anterior;
    ultimo^.siguiente := nuevo;
    nuevo^.anterior := ultimo;
    nuevo^.siguiente := lista.primero;
    lista.primero^.anterior := nuevo;
  end;
end;

procedure MostrarContactos(lista: TListaContactos; limite: Integer);
var
  aux: PContacto;
  count: Integer;
begin
  if lista.primero = nil then
  begin
    WriteLn('No hay contactos');
    Exit;
  end;

  aux := lista.primero;
  count := 0;
  repeat
    Inc(count);
    WriteLn('ID: ', aux^.id, ' | Nombre: ', aux^.nombre, ' | Email: ', aux^.email);
    aux := aux^.siguiente;
  until (aux = lista.primero) or (count = limite);
end;

function BuscarContacto(lista: TListaContactos; email: String): PContacto;
var
  aux: PContacto;
begin
  BuscarContacto := nil;
  if lista.primero = nil then Exit;

  aux := lista.primero;
  repeat
    if aux^.email = email then
    begin
      BuscarContacto := aux;
      Exit;
    end;
    aux := aux^.siguiente;
  until aux = lista.primero;
end;

end.
