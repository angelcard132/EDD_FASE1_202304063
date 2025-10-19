program Main;

uses
  gtk2, glib2,
  listasimple2, cola2, arbol_avl, arbol_b, blockchain, pila2, control_login,
  json_loader, login;

var
  usuarios: TListaSimple;
  programados: TCola;
  borradores: PCorreoAVL;
  favoritos: PNodoB;
  blockchainMail: TBlockchain;
  papelera: TPila;

begin
  // ✅ INICIALIZAR GENERADOR DE NÚMEROS ALEATORIOS
  Randomize;
  
  // Inicializar todas las estructuras
  InicializarLista(usuarios);
  InicializarCola(programados);
  arbol_avl.Inicializar(borradores);
  arbol_b.Inicializar(favoritos);
  InicializarBlockchain(blockchainMail);
  InicializarPila(papelera);

  WriteLn('🔧 DEBUG: Aplicación iniciada, generador aleatorio inicializado');

  // Inicializar GTK y mostrar login
  gtk_init(@argc, @argv);
  MostrarLogin(usuarios, programados, borradores, favoritos, blockchainMail);
  gtk_main();
  
  // Limpiar memoria al final
  LiberarBlockchain(blockchainMail);
  LiberarControlLogin();
end.
