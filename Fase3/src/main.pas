program Main;

uses
  gtk2, glib2,
  listasimple2, cola2, arbol_avl, arbol_b, blockchain, pila2, control_login, // ✅ AGREGAR control_login
  json_loader, login;

var
  usuarios: TListaSimple;
  programados: TCola;
  borradores: PCorreoAVL;
  favoritos: PNodoB;
  blockchainMail: TBlockchain;
  papelera: TPila; // ✅ AGREGAR papelera

begin
  // Inicializar todas las estructuras
  InicializarLista(usuarios);
  InicializarCola(programados);
  arbol_avl.Inicializar(borradores);
  arbol_b.Inicializar(favoritos);
  InicializarBlockchain(blockchainMail);
  InicializarPila(papelera); // ✅ INICIALIZAR papelera

  // Inicializar GTK y mostrar login
  gtk_init(@argc, @argv);
  MostrarLogin(usuarios, programados, borradores, favoritos, blockchainMail);
  gtk_main();
  
  // Limpiar memoria al final
  LiberarBlockchain(blockchainMail);
  LiberarControlLogin(); // ✅ LIMPIAR control de login
end.
