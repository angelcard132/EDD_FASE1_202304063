unit globals;

{$mode objfpc}{$H+}

interface

uses
  lista_doble, lista_simple, lista_circular, cola, pila;

var
  CorreosGlobal: TListaCorreos;  // lista de correos compartida en toda la app
  UsuarioActivo: TUsuario;       // usuario logueado actual
  ContactosUsuarioActivo: TListaContactos; // contactos del usuario actual
  ColaProgramadosUsuarioActivo: TCola; // cola de correos programados del usuario actual
  UsuariosGlobal: TListaUsuarios; // lista global de usuarios para cargar correos2.json
  PapeleraUsuarioActivo: TPila; // pila de papelera del usuario actual

procedure InicializarGlobales;
procedure CambiarUsuarioActivo(const nuevoUsuario: TUsuario);

implementation

procedure InicializarGlobales;
begin
  InicializarListaCorreos(CorreosGlobal);  // deja la lista vacía, segura
  InicializarContactos(ContactosUsuarioActivo);
  InicializarCola(ColaProgramadosUsuarioActivo);
  InicializarListaUsuarios(UsuariosGlobal);
  InicializarPila(PapeleraUsuarioActivo);
  // UsuarioActivo se llenará al hacer login
end;

procedure CambiarUsuarioActivo(const nuevoUsuario: TUsuario);
begin
  UsuarioActivo := nuevoUsuario;
  // Reinicializar contactos, cola y papelera para el nuevo usuario
  InicializarContactos(ContactosUsuarioActivo);
  InicializarCola(ColaProgramadosUsuarioActivo);
  InicializarPila(PapeleraUsuarioActivo);
end;

end.
