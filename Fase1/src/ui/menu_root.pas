unit menu_root;

{$mode objfpc}{$H+}

interface

uses
  glib2, gtk2;

procedure MostrarMenuRoot;

implementation

procedure on_carga_clicked(widget: PGtkWidget; data: gpointer); cdecl;
begin
  WriteLn('Carga masiva JSON seleccionada');
end;

procedure on_reporte_usuarios_clicked(widget: PGtkWidget; data: gpointer); cdecl;
begin
  WriteLn('Generar reporte de usuarios');
end;

procedure on_reporte_relaciones_clicked(widget: PGtkWidget; data: gpointer); cdecl;
begin
  WriteLn('Generar reporte de relaciones');
end;

procedure MostrarMenuRoot;
var
  window: PGtkWidget;
  vbox: PGtkWidget;
  btnCarga, btnRepUsuarios, btnRepRelaciones: PGtkWidget;
begin
  window := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(window), 'EDDMail - Root Menu');
  gtk_window_set_default_size(GTK_WINDOW(window), 300, 200);

  vbox := gtk_vbox_new(FALSE, 10);
  gtk_container_add(GTK_CONTAINER(window), vbox);

  btnCarga := gtk_button_new_with_label('Carga Masiva JSON');
  g_signal_connect(btnCarga, 'clicked', G_CALLBACK(@on_carga_clicked), nil);
  gtk_box_pack_start(GTK_BOX(vbox), btnCarga, FALSE, FALSE, 0);

  btnRepUsuarios := gtk_button_new_with_label('Reporte de Usuarios');
  g_signal_connect(btnRepUsuarios, 'clicked', G_CALLBACK(@on_reporte_usuarios_clicked), nil);
  gtk_box_pack_start(GTK_BOX(vbox), btnRepUsuarios, FALSE, FALSE, 0);

  btnRepRelaciones := gtk_button_new_with_label('Reporte de Relaciones');
  g_signal_connect(btnRepRelaciones, 'clicked', G_CALLBACK(@on_reporte_relaciones_clicked), nil);
  gtk_box_pack_start(GTK_BOX(vbox), btnRepRelaciones, FALSE, FALSE, 0);

  gtk_widget_show_all(window);
end;

end.
