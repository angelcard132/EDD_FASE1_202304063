unit listasimple2;

interface

type
  PUsuario = ^TUsuario;
  TUsuario = record
    id: Integer;
    nombre: String;
    usuario: String;
    email: String;
    telefono: String;
    siguiente: PUsuario;
  end;

  TListaSimple = record
    cabeza: PUsuario;
  end;

procedure InicializarLista(var lista: TListaSimple);
procedure AgregarUsuario(var lista: TListaSimple; id: Integer; nombre, usuario, email, telefono: String);
procedure MostrarUsuarios(var lista: TListaSimple);

implementation

procedure InicializarLista(var lista: TListaSimple);
begin
  lista.cabeza := nil;
end;

procedure AgregarUsuario(var lista: TListaSimple; id: Integer; nombre, usuario, email, telefono: String);
var
  nuevo, actual: PUsuario;
begin
  New(nuevo);
  nuevo^.id := id;
  nuevo^.nombre := nombre;
  nuevo^.usuario := usuario;
  nuevo^.email := email;
  nuevo^.telefono := telefono;
  nuevo^.siguiente := nil;

  if lista.cabeza = nil then
    lista.cabeza := nuevo
  else
  begin
    actual := lista.cabeza;
    while actual^.siguiente <> nil do
      actual := actual^.siguiente;
    actual^.siguiente := nuevo;
  end;
end;

procedure MostrarUsuarios(var lista: TListaSimple);
var
  actual: PUsuario;
begin
  actual := lista.cabeza;
  while actual <> nil do
  begin
    WriteLn('ID: ', actual^.id, ' | Nombre: ', actual^.nombre, ' | Usuario: ', actual^.usuario,
            ' | Email: ', actual^.email, ' | Teléfono: ', actual^.telefono);
    actual := actual^.siguiente;
  end;
end;

end.
