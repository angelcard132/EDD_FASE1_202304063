program Main;

{$mode objfpc}{$H+}

uses
  gtk2, glib2, login, globals;

begin
  gtk_init(@argc, @argv);

  // 🔹 inicializar variables globales
  InicializarGlobales;

  // abrir login
  MostrarLogin;

  gtk_main;
end.

