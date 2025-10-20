program Main;

uses
  gtk2, glib2,
  listasimple2, cola2, arbol_avl, arbol_b, blockchain, pila2, control_login, merkle_tree,
  json_loader, login;

var
  usuarios: TListaSimple;
  programados: TCola;
  borradores: PCorreoAVL;
  favoritos: PNodoB;
  blockchainMail: TBlockchain;
  papelera: TPila;
  merklePrivados: TArbolMerkle; // ✅ AGREGAR árbol de Merkle

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
  InicializarArbolMerkle(merklePrivados); // ✅ INICIALIZAR Merkle Tree

  WriteLn('🔧 DEBUG: Aplicación iniciada, todas las estructuras inicializadas');

  // Inicializar GTK y mostrar login
  gtk_init(@argc, @argv);
  MostrarLogin(usuarios, programados, borradores, favoritos, blockchainMail);
  gtk_main();
  
  // Limpiar memoria al final
  LiberarBlockchain(blockchainMail);
  LiberarControlLogin();
  LiberarArbolMerkle(merklePrivados); // ✅ LIBERAR Merkle Tree
end.
