unit perfil;

{$mode objfpc}{$H+}

interface

uses
  glib2, gtk2, SysUtils, lista_simple, globals, json_loader;

procedure MostrarPerfil;

implementation

var
  entryNombre, entryUsuario, entryEmail, entryTelefono, entryPassword: PGtkWidget;
  ventanaActualizar: PGtkWidget;

procedure ActualizarDatosUsuario;
var
  nuevoNombre, nuevoUsuario, nuevoEmail, nuevoTelefono, nuevaPassword: String;
begin
  nuevoNombre := gtk_entry_get_text(GTK_ENTRY(entryNombre));
  nuevoUsuario := gtk_entry_get_text(GTK_ENTRY(entryUsuario));
  nuevoEmail := gtk_entry_get_text(GTK_ENTRY(entryEmail));
  nuevoTelefono := gtk_entry_get_text(GTK_ENTRY(entryTelefono));
  nuevaPassword := gtk_entry_get_text(GTK_ENTRY(entryPassword));

  if (Trim(nuevoNombre) = '') or (Trim(nuevoUsuario) = '') or (Trim(nuevoEmail) = '') or 
     (Trim(nuevoTelefono) = '') or (Trim(nuevaPassword) = '') then
  begin
    WriteLn('⚠️ Todos los campos son obligatorios');
    Exit;
  end;

  // Validar formato de email básico
  if Pos('@', nuevoEmail) = 0 then
  begin
    WriteLn('⚠️ Email inválido');
    Exit;
  end;

  // Actualizar los datos del usuario activo
  UsuarioActivo.nombre := nuevoNombre;
  UsuarioActivo.usuario := nuevoUsuario;
  UsuarioActivo.email := nuevoEmail;
  UsuarioActivo.telefono := nuevoTelefono;
  UsuarioActivo.password := nuevaPassword;

  WriteLn('✅ Perfil actualizado exitosamente');
  WriteLn('   Nombre: ', nuevoNombre);
  WriteLn('   Usuario: ', nuevoUsuario);
  WriteLn('   Email: ', nuevoEmail);
  WriteLn('   Teléfono: ', nuevoTelefono);
  
  // Cerrar ventana de actualización
  gtk_widget_destroy(ventanaActualizar);
end;

procedure OnAceptarClicked(widget: PGtkWidget; data: gpointer); cdecl;
begin
  ActualizarDatosUsuario;
end;

procedure OnCancelarClicked(widget: PGtkWidget; data: gpointer); cdecl;
begin
  gtk_widget_destroy(ventanaActualizar);
end;

procedure MostrarVentanaActualizar;
var
  vbox, hbox, lbl: PGtkWidget;
  hboxBotones, btnAceptar, btnCancelar: PGtkWidget;
begin
  ventanaActualizar := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(ventanaActualizar), 'Actualizar Datos');
  gtk_window_set_default_size(GTK_WINDOW(ventanaActualizar), 400, 350);
  gtk_window_set_modal(GTK_WINDOW(ventanaActualizar), TRUE);

  vbox := gtk_vbox_new(FALSE, 8);
  gtk_container_add(GTK_CONTAINER(ventanaActualizar), vbox);

  // Título
  lbl := gtk_label_new('<b>Actualizar Información Personal</b>');
  gtk_label_set_use_markup(GTK_LABEL(lbl), TRUE);
  gtk_box_pack_start(GTK_BOX(vbox), lbl, FALSE, FALSE, 5);

  // Nombre:
  hbox := gtk_hbox_new(FALSE, 5);
  lbl := gtk_label_new('Nombre:');
  gtk_widget_set_size_request(lbl, 80, -1);
  gtk_box_pack_start(GTK_BOX(hbox), lbl, FALSE, FALSE, 5);
  entryNombre := gtk_entry_new;
  gtk_entry_set_text(GTK_ENTRY(entryNombre), PChar(UsuarioActivo.nombre));
  gtk_box_pack_start(GTK_BOX(hbox), entryNombre, TRUE, TRUE, 5);
  gtk_box_pack_start(GTK_BOX(vbox), hbox, FALSE, FALSE, 5);

  // Usuario:
  hbox := gtk_hbox_new(FALSE, 5);
  lbl := gtk_label_new('Usuario:');
  gtk_widget_set_size_request(lbl, 80, -1);
  gtk_box_pack_start(GTK_BOX(hbox), lbl, FALSE, FALSE, 5);
  entryUsuario := gtk_entry_new;
  gtk_entry_set_text(GTK_ENTRY(entryUsuario), PChar(UsuarioActivo.usuario));
  gtk_box_pack_start(GTK_BOX(hbox), entryUsuario, TRUE, TRUE, 5);
  gtk_box_pack_start(GTK_BOX(vbox), hbox, FALSE, FALSE, 5);

  // Email:
  hbox := gtk_hbox_new(FALSE, 5);
  lbl := gtk_label_new('Email:');
  gtk_widget_set_size_request(lbl, 80, -1);
  gtk_box_pack_start(GTK_BOX(hbox), lbl, FALSE, FALSE, 5);
  entryEmail := gtk_entry_new;
  gtk_entry_set_text(GTK_ENTRY(entryEmail), PChar(UsuarioActivo.email));
  gtk_box_pack_start(GTK_BOX(hbox), entryEmail, TRUE, TRUE, 5);
  gtk_box_pack_start(GTK_BOX(vbox), hbox, FALSE, FALSE, 5);

  // Teléfono:
  hbox := gtk_hbox_new(FALSE, 5);
  lbl := gtk_label_new('Teléfono:');
  gtk_widget_set_size_request(lbl, 80, -1);
  gtk_box_pack_start(GTK_BOX(hbox), lbl, FALSE, FALSE, 5);
  entryTelefono := gtk_entry_new;
  gtk_entry_set_text(GTK_ENTRY(entryTelefono), PChar(UsuarioActivo.telefono));
  gtk_box_pack_start(GTK_BOX(hbox), entryTelefono, TRUE, TRUE, 5);
  gtk_box_pack_start(GTK_BOX(vbox), hbox, FALSE, FALSE, 5);

  // Password:
  hbox := gtk_hbox_new(FALSE, 5);
  lbl := gtk_label_new('Contraseña:');
  gtk_widget_set_size_request(lbl, 80, -1);
  gtk_box_pack_start(GTK_BOX(hbox), lbl, FALSE, FALSE, 5);
  entryPassword := gtk_entry_new;
  gtk_entry_set_text(GTK_ENTRY(entryPassword), PChar(UsuarioActivo.password));
  gtk_entry_set_visibility(GTK_ENTRY(entryPassword), FALSE);
  gtk_box_pack_start(GTK_BOX(hbox), entryPassword, TRUE, TRUE, 5);
  gtk_box_pack_start(GTK_BOX(vbox), hbox, FALSE, FALSE, 5);

  // Botones
  hboxBotones := gtk_hbox_new(TRUE, 10);
  gtk_box_pack_start(GTK_BOX(vbox), hboxBotones, FALSE, FALSE, 15);

  btnAceptar := gtk_button_new_with_label('✓ Aceptar');
  g_signal_connect(btnAceptar, 'clicked', G_CALLBACK(@OnAceptarClicked), nil);
  gtk_box_pack_start(GTK_BOX(hboxBotones), btnAceptar, TRUE, TRUE, 5);

  btnCancelar := gtk_button_new_with_label('✗ Cancelar');
  g_signal_connect(btnCancelar, 'clicked', G_CALLBACK(@OnCancelarClicked), nil);
  gtk_box_pack_start(GTK_BOX(hboxBotones), btnCancelar, TRUE, TRUE, 5);

  gtk_widget_show_all(ventanaActualizar);
end;

procedure OnActualizarClicked(widget: PGtkWidget; data: gpointer); cdecl;
begin
  MostrarVentanaActualizar;
end;

procedure MostrarPerfil;
var
  window, vbox, hbox, lbl, lblValor: PGtkWidget;
  btnActualizar: PGtkWidget;
  tituloUsuario: String;
begin
  window := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(window), 'Mi Perfil');
  gtk_window_set_default_size(GTK_WINDOW(window), 450, 400);

  vbox := gtk_vbox_new(FALSE, 10);
  gtk_container_add(GTK_CONTAINER(window), vbox);

  // Título con usuario actual
  tituloUsuario := 'Perfil de Usuario: ' + UsuarioActivo.nombre;
  lbl := gtk_label_new(PChar('<b>' + tituloUsuario + '</b>'));
  gtk_label_set_use_markup(GTK_LABEL(lbl), TRUE);
  gtk_box_pack_start(GTK_BOX(vbox), lbl, FALSE, FALSE, 10);

  // ID:
  hbox := gtk_hbox_new(FALSE, 10);
  lbl := gtk_label_new('<b>ID:</b>');
  gtk_label_set_use_markup(GTK_LABEL(lbl), TRUE);
  gtk_widget_set_size_request(lbl, 100, -1);
  gtk_box_pack_start(GTK_BOX(hbox), lbl, FALSE, FALSE, 5);
  lblValor := gtk_label_new(PChar(IntToStr(UsuarioActivo.id)));
  gtk_label_set_selectable(GTK_LABEL(lblValor), TRUE);
  gtk_box_pack_start(GTK_BOX(hbox), lblValor, TRUE, TRUE, 5);
  gtk_box_pack_start(GTK_BOX(vbox), hbox, FALSE, FALSE, 5);

  // Nombre:
  hbox := gtk_hbox_new(FALSE, 10);
  lbl := gtk_label_new('<b>Nombre:</b>');
  gtk_label_set_use_markup(GTK_LABEL(lbl), TRUE);
  gtk_widget_set_size_request(lbl, 100, -1);
  gtk_box_pack_start(GTK_BOX(hbox), lbl, FALSE, FALSE, 5);
  lblValor := gtk_label_new(PChar(UsuarioActivo.nombre));
  gtk_label_set_selectable(GTK_LABEL(lblValor), TRUE);
  gtk_box_pack_start(GTK_BOX(hbox), lblValor, TRUE, TRUE, 5);
  gtk_box_pack_start(GTK_BOX(vbox), hbox, FALSE, FALSE, 5);

  // Usuario:
  hbox := gtk_hbox_new(FALSE, 10);
  lbl := gtk_label_new('<b>Usuario:</b>');
  gtk_label_set_use_markup(GTK_LABEL(lbl), TRUE);
  gtk_widget_set_size_request(lbl, 100, -1);
  gtk_box_pack_start(GTK_BOX(hbox), lbl, FALSE, FALSE, 5);
  lblValor := gtk_label_new(PChar(UsuarioActivo.usuario));
  gtk_label_set_selectable(GTK_LABEL(lblValor), TRUE);
  gtk_box_pack_start(GTK_BOX(hbox), lblValor, TRUE, TRUE, 5);
  gtk_box_pack_start(GTK_BOX(vbox), hbox, FALSE, FALSE, 5);

  // Email:
  hbox := gtk_hbox_new(FALSE, 10);
  lbl := gtk_label_new('<b>Email:</b>');
  gtk_label_set_use_markup(GTK_LABEL(lbl), TRUE);
  gtk_widget_set_size_request(lbl, 100, -1);
  gtk_box_pack_start(GTK_BOX(hbox), lbl, FALSE, FALSE, 5);
  lblValor := gtk_label_new(PChar(UsuarioActivo.email));
  gtk_label_set_selectable(GTK_LABEL(lblValor), TRUE);
  gtk_box_pack_start(GTK_BOX(hbox), lblValor, TRUE, TRUE, 5);
  gtk_box_pack_start(GTK_BOX(vbox), hbox, FALSE, FALSE, 5);

  // Teléfono:
  hbox := gtk_hbox_new(FALSE, 10);
  lbl := gtk_label_new('<b>Teléfono:</b>');
  gtk_label_set_use_markup(GTK_LABEL(lbl), TRUE);
  gtk_widget_set_size_request(lbl, 100, -1);
  gtk_box_pack_start(GTK_BOX(hbox), lbl, FALSE, FALSE, 5);
  lblValor := gtk_label_new(PChar(UsuarioActivo.telefono));
  gtk_label_set_selectable(GTK_LABEL(lblValor), TRUE);
  gtk_box_pack_start(GTK_BOX(hbox), lblValor, TRUE, TRUE, 5);
  gtk_box_pack_start(GTK_BOX(vbox), hbox, FALSE, FALSE, 5);

  // Contraseña (oculta):
  hbox := gtk_hbox_new(FALSE, 10);
  lbl := gtk_label_new('<b>Contraseña:</b>');
  gtk_label_set_use_markup(GTK_LABEL(lbl), TRUE);
  gtk_widget_set_size_request(lbl, 100, -1);
  gtk_box_pack_start(GTK_BOX(hbox), lbl, FALSE, FALSE, 5);
  lblValor := gtk_label_new('••••••••');
  gtk_box_pack_start(GTK_BOX(hbox), lblValor, TRUE, TRUE, 5);
  gtk_box_pack_start(GTK_BOX(vbox), hbox, FALSE, FALSE, 5);

  // Botón actualizar
  btnActualizar := gtk_button_new_with_label('✏️ Actualizar Datos');
  g_signal_connect(btnActualizar, 'clicked', G_CALLBACK(@OnActualizarClicked), nil);
  gtk_box_pack_start(GTK_BOX(vbox), btnActualizar, FALSE, FALSE, 20);

  gtk_widget_show_all(window);
end;

end.
  gtk_box_pack_start(GTK_BOX(vbox), btnActualizar, FALSE, FALSE, 20);

  gtk_widget_show_all(window);
end;

end.
