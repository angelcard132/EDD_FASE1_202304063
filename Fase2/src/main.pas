program Main;

uses
  gtk2, glib2,
  listasimple2, cola2, arbol_avl, arbol_b,
  json_loader, login;

var
  usuarios: TListaSimple;
  programados: TCola;
  borradores: PCorreoAVL;
  favoritos: PNodoB;

begin
  InicializarLista(usuarios);
  InicializarCola(programados);
  arbol_avl.Inicializar(borradores);
  arbol_b.Inicializar(favoritos);

  gtk_init(@argc, @argv);
  MostrarLogin(usuarios, programados, borradores, favoritos);
  gtk_main();
end.
  gtk_init(@argc, @argv);
  MostrarLogin(usuarios, programados, borradores, favoritos);
  gtk_main();
end.
