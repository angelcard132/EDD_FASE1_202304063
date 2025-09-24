unit menuusuario;

{$mode objfpc}{$H+}

interface

uses
  glib2, gtk2, gdk2, SysUtils,
  listasimple2, cola2, arbol_avl, arbol_b, json_loader;

procedure MostrarMenuUsuario(const email: String; var usuarios: TListaSimple; var programados: TCola; var borradores: PCorreoAVL; var favoritos: PNodoB);

implementation

procedure OnCerrarSesionUsuario(widget: PGtkWidget; data: gpointer); cdecl;
begin
  // Cerrar ventana actual y volver al login
  if Assigned(widget) then
    gtk_widget_destroy(gtk_widget_get_toplevel(widget));
  
  WriteLn('Sesión cerrada - regresando al login');
end;

procedure MostrarMenuUsuario(const email: String; var usuarios: TListaSimple; var programados: TCola; var borradores: PCorreoAVL; var favoritos: PNodoB);
var
  w, vbox, lbl, btnBorr, btnFav, btnProg, btnSalir: PGtkWidget;
  nombre: String;
begin
  // Las estructuras se pasan por parámetro, no necesitamos variables globales aquí
  
  nombre := NombreDeEmail(email);
  w := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(w), PChar('Menú de Usuario - ' + nombre));
  gtk_window_set_default_size(GTK_WINDOW(w), 480, 320);
  gtk_container_set_border_width(GTK_CONTAINER(w), 16);

  vbox := gtk_vbox_new(False, 12);
  gtk_container_add(GTK_CONTAINER(w), vbox);

  lbl := gtk_label_new(PChar('Bienvenido, ' + nombre + ' (' + email + ')'));
  gtk_box_pack_start(GTK_BOX(vbox), lbl, False, False, 10);

  btnProg := gtk_button_new_with_label('Ver Programados (Cola)');
  g_signal_connect(btnProg, 'clicked', G_CALLBACK(@g_print), gpointer(PChar('>> Programados: vista no implementada' + LineEnding)));
  gtk_box_pack_start(GTK_BOX(vbox), btnProg, True, True, 5);

  btnBorr := gtk_button_new_with_label('Ver Borradores (AVL)');
  g_signal_connect(btnBorr, 'clicked', G_CALLBACK(@g_print), gpointer(PChar('>> Borradores: vista no implementada' + LineEnding)));
  gtk_box_pack_start(GTK_BOX(vbox), btnBorr, True, True, 5);

  btnFav := gtk_button_new_with_label('Ver Favoritos (B-Tree)');
  g_signal_connect(btnFav, 'clicked', G_CALLBACK(@g_print), gpointer(PChar('>> Favoritos: vista no implementada' + LineEnding)));
  gtk_box_pack_start(GTK_BOX(vbox), btnFav, True, True, 5);

  btnSalir := gtk_button_new_with_label('Cerrar sesión');
  g_signal_connect(btnSalir, 'clicked', G_CALLBACK(@OnCerrarSesionUsuario), nil);
  gtk_box_pack_start(GTK_BOX(vbox), btnSalir, True, True, 5);

  gtk_widget_show_all(w);
end;

end.
  g_signal_connect(btnFav, 'clicked', G_CALLBACK(@g_print), gpointer(PChar('>> Favoritos: vista no implementada' + LineEnding)));
  gtk_box_pack_start(GTK_BOX(vbox), btnFav, True, True, 5);

  btnSalir := gtk_button_new_with_label('Cerrar sesión');
  g_signal_connect(btnSalir, 'clicked', G_CALLBACK(@OnCerrarSesionUsuario), nil);
  gtk_box_pack_start(GTK_BOX(vbox), btnSalir, True, True, 5);

  gtk_widget_show_all(w);
end;

end.
