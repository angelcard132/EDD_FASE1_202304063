unit menu_usuario;

{$mode objfpc}{$H+}

interface

uses
  glib2, gtk2, bandeja, lista_doble, json_loader    ;

procedure MostrarMenuUsuario;

implementation

var
  correos: TListaCorreos; // Lista de correos del usuario actual

// 🔹 Callbacks de botones
procedure on_bandeja_clicked(widget: PGtkWidget; data: gpointer); cdecl;
begin
  MostrarBandeja(correos);
end;

procedure on_enviar_clicked(widget: PGtkWidget; data: gpointer); cdecl;
begin
  WriteLn('Abrir ventana para ENVIAR CORREO');
end;

procedure on_programar_clicked(widget: PGtkWidget; data: gpointer); cdecl;
begin
  WriteLn('Abrir ventana para PROGRAMAR CORREO');
end;

procedure on_papelera_clicked(widget: PGtkWidget; data: gpointer); cdecl;
begin
  WriteLn('Abrir PAPELERA');
end;

procedure on_contactos_clicked(widget: PGtkWidget; data: gpointer); cdecl;
begin
  WriteLn('Abrir CONTACTOS');
end;

procedure on_actualizar_clicked(widget: PGtkWidget; data: gpointer); cdecl;
begin
  WriteLn('Abrir ACTUALIZAR PERFIL');
end;

procedure on_reportes_clicked(widget: PGtkWidget; data: gpointer); cdecl;
begin
  WriteLn('Abrir REPORTES de usuario');
end;

// 🔹 Ventana principal de menú usuario
procedure MostrarMenuUsuario;
var
  window: PGtkWidget;
  vbox: PGtkWidget;
  btnBandeja, btnEnviar, btnProgramar, btnPapelera,
  btnContactos, btnActualizar, btnReportes: PGtkWidget;
begin
  // Inicializar lista de correos
  InicializarListaCorreos(correos);

  // 🔹 Cargar desde JSON en vez de quemar datos
  CargarCorreosDesdeJSON('../assets/correos.json', correos);
  // Crear ventana
  window := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(window), 'EDDMail - Menú Usuario');
  gtk_window_set_default_size(GTK_WINDOW(window), 300, 400);

  vbox := gtk_vbox_new(FALSE, 10);
  gtk_container_add(GTK_CONTAINER(window), vbox);

  // Botones
  btnBandeja := gtk_button_new_with_label('Bandeja de Entrada');
  g_signal_connect(btnBandeja, 'clicked', G_CALLBACK(@on_bandeja_clicked), nil);
  gtk_box_pack_start(GTK_BOX(vbox), btnBandeja, FALSE, FALSE, 0);

  btnEnviar := gtk_button_new_with_label('Enviar Correo');
  g_signal_connect(btnEnviar, 'clicked', G_CALLBACK(@on_enviar_clicked), nil);
  gtk_box_pack_start(GTK_BOX(vbox), btnEnviar, FALSE, FALSE, 0);

  btnProgramar := gtk_button_new_with_label('Programar Correo');
  g_signal_connect(btnProgramar, 'clicked', G_CALLBACK(@on_programar_clicked), nil);
  gtk_box_pack_start(GTK_BOX(vbox), btnProgramar, FALSE, FALSE, 0);

  btnPapelera := gtk_button_new_with_label('Papelera');
  g_signal_connect(btnPapelera, 'clicked', G_CALLBACK(@on_papelera_clicked), nil);
  gtk_box_pack_start(GTK_BOX(vbox), btnPapelera, FALSE, FALSE, 0);

  btnContactos := gtk_button_new_with_label('Contactos');
  g_signal_connect(btnContactos, 'clicked', G_CALLBACK(@on_contactos_clicked), nil);
  gtk_box_pack_start(GTK_BOX(vbox), btnContactos, FALSE, FALSE, 0);

  btnActualizar := gtk_button_new_with_label('Actualizar Perfil');
  g_signal_connect(btnActualizar, 'clicked', G_CALLBACK(@on_actualizar_clicked), nil);
  gtk_box_pack_start(GTK_BOX(vbox), btnActualizar, FALSE, FALSE, 0);

  btnReportes := gtk_button_new_with_label('Reportes');
  g_signal_connect(btnReportes, 'clicked', G_CALLBACK(@on_reportes_clicked), nil);
  gtk_box_pack_start(GTK_BOX(vbox), btnReportes, FALSE, FALSE, 0);

  // Mostrar ventana
  gtk_widget_show_all(window);
end;

end.
