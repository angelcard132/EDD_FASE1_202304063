unit menu_usuario;

{$mode objfpc}{$H+}

interface

uses
  glib2, gtk2, bandeja, redactar, lista_doble, lista_simple, globals, enviados, papelera, programar_correo, agregar_contacto, perfil;

procedure MostrarMenuUsuario(const usuario: TUsuario);

implementation

// Abrir bandeja (usa UsuarioActivo global)
procedure OnBandejaClicked(widget: PGtkWidget; data: gpointer); cdecl;
begin
  MostrarBandeja(UsuarioActivo);
end;

procedure OnPapeleraClicked(widget: PGtkWidget; data: gpointer); cdecl;
begin
  MostrarPapelera();
end;

// Abrir ventana de redacción (usa globals)
procedure OnRedactarClicked(widget: PGtkWidget; data: gpointer); cdecl;
begin
  MostrarRedactar(); // ahora no pasamos punteros; usa globals
end;

procedure OnEnviadosClicked(widget: PGtkWidget; data: gpointer); cdecl;
begin
  MostrarEnviados();
end;

procedure OnProgramarClicked(widget: PGtkWidget; data: gpointer); cdecl;
begin
  MostrarProgramarCorreo();
end;

procedure OnAgregarContactoClicked(widget: PGtkWidget; data: gpointer); cdecl;
begin
  MostrarAgregarContacto();
end;

procedure OnPerfilClicked(widget: PGtkWidget; data: gpointer); cdecl;
begin
  MostrarPerfil();
end;

procedure MostrarMenuUsuario(const usuario: TUsuario);
var
  window, vbox, btnBandeja, btnEnviados, btnRedactar, btnPapelera, btnProgramar, btnContactos, btnPerfil: PGtkWidget;
begin
  // Guardar el usuario activo en un lugar GLOBAL (puntero estable)
  UsuarioActivo := usuario;

  // Asegurar que la lista global exista
  if (CorreosGlobal.primero = nil) and (CorreosGlobal.ultimo = nil) then
    InicializarListaCorreos(CorreosGlobal);

  window := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(window), PChar('Menú Usuario - ' + UsuarioActivo.email));
  gtk_window_set_default_size(GTK_WINDOW(window), 300, 200);

  vbox := gtk_vbox_new(FALSE, 5);
  gtk_container_add(GTK_CONTAINER(window), vbox);

  // Botón: Bandeja
  btnBandeja := gtk_button_new_with_label('📥 Bandeja de entrada');
  g_signal_connect(btnBandeja, 'clicked', G_CALLBACK(@OnBandejaClicked), nil);
  gtk_box_pack_start(GTK_BOX(vbox), btnBandeja, FALSE, FALSE, 5);
  // Botón: Enviados
  btnEnviados := gtk_button_new_with_label('📤 Enviados');
  g_signal_connect(btnEnviados, 'clicked', G_CALLBACK(@OnEnviadosClicked), nil);
  gtk_box_pack_start(GTK_BOX(vbox), btnEnviados, FALSE, FALSE, 5);
  // Botón: Redactar
  btnRedactar := gtk_button_new_with_label('✉️ Redactar correo');
  g_signal_connect(btnRedactar, 'clicked', G_CALLBACK(@OnRedactarClicked), nil);
  gtk_box_pack_start(GTK_BOX(vbox), btnRedactar, FALSE, FALSE, 5);
  // Botón: Papelera
  btnPapelera := gtk_button_new_with_label('🗑️ Papelera');
  g_signal_connect(btnPapelera, 'clicked', G_CALLBACK(@OnPapeleraClicked), nil);
  gtk_box_pack_start(GTK_BOX(vbox), btnPapelera, FALSE, FALSE, 5);
  // Botón: Programar Correo
  btnProgramar := gtk_button_new_with_label('⏰ Programar correo');
  g_signal_connect(btnProgramar, 'clicked', G_CALLBACK(@OnProgramarClicked), nil);
  gtk_box_pack_start(GTK_BOX(vbox), btnProgramar, FALSE, FALSE, 5);
  // Botón: Agregar Contacto
  btnContactos := gtk_button_new_with_label('👥 Agregar Contacto');
  g_signal_connect(btnContactos, 'clicked', G_CALLBACK(@OnAgregarContactoClicked), nil);
  gtk_box_pack_start(GTK_BOX(vbox), btnContactos, FALSE, FALSE, 5);
  // Botón: Perfil
  btnPerfil := gtk_button_new_with_label('👤 Perfil');
  g_signal_connect(btnPerfil, 'clicked', G_CALLBACK(@OnPerfilClicked), nil);
  gtk_box_pack_start(GTK_BOX(vbox), btnPerfil, FALSE, FALSE, 5);

  gtk_widget_show_all(window);
end;

end.
