unit root_menu;

{$mode objfpc}{$H+}

interface

uses
  glib2, gtk2, gdk2, SysUtils,
  listasimple2, cola2, arbol_avl, arbol_b, json_loader, login; // <-- agregar login

procedure MostrarMenuRoot;

implementation

var
  usuarios: TListaSimple;
  programados: TCola;
  borradores: PCorreoAVL;
  favoritos: PNodoB;

{ --- Callbacks --- }

procedure OnCargaMasiva(widget: PGtkWidget; data: gpointer); cdecl;
begin
  InicializarLista(usuarios);
  InicializarCola(programados);
  arbol_avl.Inicializar(borradores);
  arbol_b.Inicializar(favoritos);

  // Carga masiva unificada (permite recargar si se desea)
  CargaMasivaDesdeJSON('/home/angel/Desktop/EDD_FASE1_202304063/Fase2/assets/usuarios.json', '/home/angel/Desktop/EDD_FASE1_202304063/Fase2/assets/correos.json',
                       usuarios, programados, borradores, favoritos);

  g_print('>> ✅ Carga masiva completada.' + LineEnding);

  gtk_message_dialog_new(nil,
    GTK_DIALOG_MODAL,
    GTK_MESSAGE_INFO,
    GTK_BUTTONS_OK,
    'Carga masiva completada correctamente.');
end;

procedure OnCrearComunidad(widget: PGtkWidget; data: gpointer); cdecl;
begin
  g_print('>> Crear comunidad (pendiente de implementar)' + LineEnding);
end;

procedure OnReporteComunidades(widget: PGtkWidget; data: gpointer); cdecl;
begin
  g_print('>> Reporte de comunidades (pendiente de implementar)' + LineEnding);
end;

procedure OnVerMensajes(widget: PGtkWidget; data: gpointer); cdecl;
begin
  g_print('>> Ver mensajes de comunidad (pendiente de implementar)' + LineEnding);
end;

procedure OnSalir(widget: PGtkWidget; data: gpointer); cdecl;
begin
  // Cerrar ventana actual y regresar al login
  if Assigned(widget) then
    gtk_widget_destroy(gtk_widget_get_toplevel(widget));
  
  // Reabrir login para que usuarios normales puedan autenticarse
  MostrarLogin(usuarios, programados, borradores, favoritos);
end;

{ --- Ventana principal --- }

procedure MostrarMenuRoot;
var
  window: PGtkWidget;
  vbox: PGtkWidget;
  btnCarga, btnComunidad, btnReporte, btnMensajes, btnSalir: PGtkWidget;
begin
  InicializarLista(usuarios);
  InicializarCola(programados);
  arbol_avl.Inicializar(borradores);
  arbol_b.Inicializar(favoritos);

  // Nota: NO llamar gtk_init aquí; ya fue llamado en main.pas

  { Ventana }
  window := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(window), 'Menú Root - EDDMail');
  gtk_window_set_default_size(GTK_WINDOW(window), 400, 300);
  gtk_container_set_border_width(GTK_CONTAINER(window), 20);

  g_signal_connect(window, 'destroy', G_CALLBACK(@OnSalir), nil);

  { Caja vertical }
  vbox := gtk_vbox_new(True, 10);
  gtk_container_add(GTK_CONTAINER(window), vbox);

  { Botones }
  btnCarga := gtk_button_new_with_label('1. Carga masiva JSON');
  g_signal_connect(btnCarga, 'clicked', G_CALLBACK(@OnCargaMasiva), nil);
  gtk_box_pack_start(GTK_BOX(vbox), btnCarga, True, True, 0);

  btnComunidad := gtk_button_new_with_label('2. Crear comunidad');
  g_signal_connect(btnComunidad, 'clicked', G_CALLBACK(@OnCrearComunidad), nil);
  gtk_box_pack_start(GTK_BOX(vbox), btnComunidad, True, True, 0);

  btnReporte := gtk_button_new_with_label('3. Reporte de comunidades');
  g_signal_connect(btnReporte, 'clicked', G_CALLBACK(@OnReporteComunidades), nil);
  gtk_box_pack_start(GTK_BOX(vbox), btnReporte, True, True, 0);

  btnMensajes := gtk_button_new_with_label('4. Ver mensajes de comunidad');
  g_signal_connect(btnMensajes, 'clicked', G_CALLBACK(@OnVerMensajes), nil);
  gtk_box_pack_start(GTK_BOX(vbox), btnMensajes, True, True, 0);

  btnSalir := gtk_button_new_with_label('Salir');
  g_signal_connect(btnSalir, 'clicked', G_CALLBACK(@OnSalir), nil);
  gtk_box_pack_start(GTK_BOX(vbox), btnSalir, True, True, 0);

  gtk_widget_show_all(window);

  // Nota: NO llamar gtk_main aquí; el loop corre en main.pas
end;

end.
