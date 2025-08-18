program main;

{$mode objfpc}{$H+}
uses
  crt, lista_simple, lista_doble, lista_circular, cola, pila, matriz_dispersa, json_loader;

var
  usuarios: TListaUsuarios;
  correos: TListaCorreos;
  contactos: TListaContactos;
  programados: TCola;
  papelera: TPila;
  relaciones: TMatriz;

begin
  InicializarLista(usuarios);
  InicializarListaCorreos(correos);
  InicializarContactos(contactos);
  InicializarCola(programados);
  InicializarPila(papelera);
  InicializarMatriz(relaciones);

  // --- Simulación de relaciones ---
  InsertarRelacion(relaciones, 'aux-luis@edd.com', 'aux-marcos@edd.com');
  InsertarRelacion(relaciones, 'aux-luis@edd.com', 'aux-marcos@edd.com');
  InsertarRelacion(relaciones, 'aux-marcos@edd.com', 'aux-luis@edd.com');
  InsertarRelacion(relaciones, 'aux-steven@edd.com', 'aux-luis@edd.com');

  WriteLn(#10, 'Relaciones de correos enviados:');
  MostrarRelaciones(relaciones);
      WriteLn(#10, 'Cantidad de correos no leídos: ', ContarNoLeidos(correos));

  WriteLn(#10, 'Correos ordenados por asunto A-Z:');
  OrdenarCorreosPorAsunto(correos);
  MostrarCorreos(correos);
    WriteLn('Presione una tecla para continuar...');

    CargarUsuariosDesdeJSON('../assets/usuarios.json', usuarios);
    WriteLn('Usuarios cargados desde JSON:');
    WriteLn('Usuarios después de carga masiva:');
    MostrarUsuarios(usuarios);


  ReadLn;
end.
