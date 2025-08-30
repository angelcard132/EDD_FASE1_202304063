unit lista_simple;

{$mode objfpc}{$H+}

interface

type
  PUsuario = ^TUsuario;
  TUsuario = record
    id: Integer;
    nombre: String;
    usuario: String;
    password: String;
    email: String;
    telefono: String;
    siguiente: PUsuario;
  end;

  TListaUsuarios = record
    primero: PUsuario;
  end;

procedure InicializarListaUsuarios(var lista: TListaUsuarios);
procedure InsertarUsuario(var lista: TListaUsuarios; id: Integer; nombre, usuario, password, email, telefono: String);
procedure MostrarUsuarios(const lista: TListaUsuarios);
function BuscarUsuarioPorEmail(const lista: TListaUsuarios; const email: String): PUsuario;

implementation

procedure InicializarListaUsuarios(var lista: TListaUsuarios);
begin
  lista.primero := nil;
end;

procedure InsertarUsuario(var lista: TListaUsuarios; id: Integer; nombre, usuario, password, email, telefono: String);
var
  nuevo, aux: PUsuario;
begin
  New(nuevo);
  nuevo^.id := id;
  nuevo^.nombre := nombre;
  nuevo^.usuario := usuario;
  nuevo^.password := password;
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

procedure MostrarUsuarios(const lista: TListaUsuarios);
var
  aux: PUsuario;
begin
  aux := lista.primero;
  while aux <> nil do
  begin
    WriteLn('ID: ', aux^.id, ' | Nombre: ', aux^.nombre, ' | Usuario: ', aux^.usuario,
            ' | Email: ', aux^.email, ' | Contraseña: ', aux^.password, ' | Tel: ', aux^.telefono);
    aux := aux^.siguiente;
  end;
end;

function BuscarUsuarioPorEmail(const lista: TListaUsuarios; const email: String): PUsuario;
var
  aux: PUsuario;
begin
  aux := lista.primero;
  while (aux <> nil) and (LowerCase(aux^.email) <> LowerCase(email)) do
    aux := aux^.siguiente;
  BuscarUsuarioPorEmail := aux;
end;

end.
function ObtenerSiguienteID(const lista: TListaUsuarios): Integer;
var
  aux: PUsuario;
  maxid: Integer;
begin
  maxid := 0;
  aux := lista.primero;
  while aux <> nil do
  begin
    if aux^.id > maxid then maxid := aux^.id;
    aux := aux^.siguiente;
  end;
  ObtenerSiguienteID := maxid + 1;
end;

end.
