unit lista_simple;

{$mode objfpc}{$H+}

interface

type
  // Nodo de usuario
  PUsuario = ^TUsuario;
  TUsuario = record
    id: Integer;
    nombre: String;
    usuario: String;
    email: String;
    telefono: String;
    siguiente: PUsuario;
  end;

  // Lista simple
  TListaUsuarios = record
    primero: PUsuario;
  end;

procedure InicializarLista(var lista: TListaUsuarios);
procedure InsertarUsuario(var lista: TListaUsuarios; id: Integer; nombre, usuario, email, telefono: String);
procedure MostrarUsuarios(lista: TListaUsuarios);
function BuscarUsuario(lista: TListaUsuarios; email: String): PUsuario;

implementation

procedure InicializarLista(var lista: TListaUsuarios);
begin
  lista.primero := nil;
end;

procedure InsertarUsuario(var lista: TListaUsuarios; id: Integer; nombre, usuario, email, telefono: String);
var
  nuevo, aux: PUsuario;
begin
  New(nuevo);
  nuevo^.id := id;
  nuevo^.nombre := nombre;
  nuevo^.usuario := usuario;
  nuevo^.email := email;
  nuevo^.telefono := telefono;
  nuevo^.siguiente := nil;

  if lista.primero = nil then
    lista.primero := nuevo
  else
  begin
    aux := lista.primero;
    while aux^.siguiente <> nil do
      aux := aux^.siguiente;
    aux^.siguiente := nuevo;
  end;
end;

procedure MostrarUsuarios(lista: TListaUsuarios);
var
  aux: PUsuario;
begin
  aux := lista.primero;
  while aux <> nil do
  begin
    WriteLn('ID: ', aux^.id, ' | Nombre: ', aux^.nombre, ' | Usuario: ', aux^.usuario, ' | Email: ', aux^.email, ' | Tel: ', aux^.telefono);
    aux := aux^.siguiente;
  end;
end;

function BuscarUsuario(lista: TListaUsuarios; email: String): PUsuario;
var
  aux: PUsuario;
begin
  aux := lista.primero;
  while (aux <> nil) and (aux^.email <> email) do
    aux := aux^.siguiente;
  BuscarUsuario := aux;
end;

end.
