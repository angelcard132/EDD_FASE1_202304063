program main;

{$mode objfpc}{$H+}

uses
  crt, lista_simple, lista_doble, lista_circular, cola, pila;

var
  usuarios: TListaUsuarios;
  correos: TListaCorreos;
  contactos: TListaContactos;
  programados: TCola;
  papelera: TPila;
  u: PUsuario;
  c: PCorreo;
  con: PContacto;
  prog: PCorreoCola;
  elim: PCorreoPila;

begin
  InicializarLista(usuarios);
  InicializarListaCorreos(correos);
  InicializarContactos(contactos);
  InicializarCola(programados);
  InicializarPila(papelera);

  // --- Usuarios ---
  InsertarUsuario(usuarios, 1, 'Luis Garcia', 'auxluis', 'aux-luis@edd.com', '12345678');
  InsertarUsuario(usuarios, 2, 'Marcos Itzep', 'auxmarcos', 'aux-marcos@edd.com', '87654321');
  WriteLn('Usuarios registrados:');
  MostrarUsuarios(usuarios);

  // --- Correos ---
  InsertarCorreo(correos, 1, 'auxluis', 'NL', 'Proyecto EDD', '17/08/2025', 'Hola Marcos, revisa el proyecto.', False);
  InsertarCorreo(correos, 2, 'auxmarcos', 'NL', 'Re: Proyecto EDD', '17/08/2025', 'Hola Luis, ya lo revisé.', False);

  WriteLn(#10, 'Correos en bandeja de entrada:');
  MostrarCorreos(correos);

  // Simular eliminación de correo
  c := BuscarCorreoPorAsunto(correos, 'Re: Proyecto');
  if c <> nil then
  begin
    // Guardar en papelera antes de eliminar
    Push(papelera, c^.id, c^.remitente, c^.asunto, c^.fecha, c^.mensaje);
    EliminarCorreo(correos, c^.id);
  end;

  WriteLn(#10, 'Correos después de mover uno a papelera:');
  MostrarCorreos(correos);

  WriteLn(#10, 'Correos en papelera:');
  MostrarPila(papelera);

  elim := BuscarEnPapelera(papelera, 'Re:');
  if elim <> nil then
    WriteLn('Correo encontrado en papelera: ', elim^.asunto);

  elim := Pop(papelera);
  if elim <> nil then
  begin
    WriteLn(#10, 'Se eliminó definitivamente: ', elim^.asunto);
    Dispose(elim);
  end;

  WriteLn(#10, 'Papelera después de eliminar uno:');
  MostrarPila(papelera);

  ReadLn;
end.
