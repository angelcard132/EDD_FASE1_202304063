unit globals;

{$mode objfpc}{$H+}

interface

uses
  lista_doble, lista_simple, lista_circular, cola, pila, comunidades;

var
  CorreosGlobal: TListaCorreos;
  UsuarioActivo: TUsuario;
  ContactosUsuarioActivo: TListaContactos;
  ColaProgramadosUsuarioActivo: TCola;
  UsuariosGlobal: TListaUsuarios;
  PapeleraUsuarioActivo: TPila;
  ComunidadesGlobal: TListaComunidades;

procedure InicializarGlobales;
procedure CambiarUsuarioActivo(const nuevoUsuario: TUsuario);

implementation

procedure InicializarGlobales;
begin
  InicializarListaCorreos(CorreosGlobal);
  InicializarContactos(ContactosUsuarioActivo);
  InicializarCola(ColaProgramadosUsuarioActivo);
  InicializarListaUsuarios(UsuariosGlobal);
  InicializarPila(PapeleraUsuarioActivo);
  InicializarListaComunidades(ComunidadesGlobal);
end;

procedure CambiarUsuarioActivo(const nuevoUsuario: TUsuario);
begin
  UsuarioActivo := nuevoUsuario;
  InicializarContactos(ContactosUsuarioActivo);
  InicializarCola(ColaProgramadosUsuarioActivo);
  InicializarPila(PapeleraUsuarioActivo);
end;

end.
  InicializarCola(ColaProgramadosUsuarioActivo);
  InicializarPila(PapeleraUsuarioActivo);
end;

end.
  InicializarContactos(ContactosUsuarioActivo);
  InicializarCola(ColaProgramadosUsuarioActivo);
  InicializarPila(PapeleraUsuarioActivo);
end;

end.
end;

end.
