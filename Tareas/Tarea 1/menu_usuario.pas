unit menu_usuario;

{$mode objfpc}{$H+}

interface

uses
  glib2, gtk2, bandeja, redactar, lista_doble, lista_simple, graphviz;

var
  UsuarioActivo: TUsuario;
  CorreosGlobal: TListaCorreos;
  UsuariosGlobal: TListaUsuarios;

procedure MostrarMenuUsuario(const usuario: TUsuario);
procedure SetGlobalData(var usuarios: TListaUsuarios; var correos: TListaCorreos);

implementation

procedure SetGlobalData(var usuarios: TListaUsuarios; var correos: TListaCorreos);
begin
  UsuariosGlobal := usuarios;
  CorreosGlobal := correos;
end;

procedure OnBandejaClicked(widget: PGtkWidget; data: gpointer); cdecl;
begin
  MostrarBandeja(UsuarioActivo, CorreosGlobal);
end;

procedure OnRedactarClicked(widget: PGtkWidget; data: gpointer); cdecl;
begin
  MostrarRedactar(UsuarioActivo, CorreosGlobal);
end;

procedure OnGenerarGraficosClicked(widget: PGtkWidget; data: gpointer); cdecl;
begin
  WriteLn('🎨 Iniciando generación de gráficos...');
  GenerarTodosLosGraficos(UsuariosGlobal, CorreosGlobal, UsuarioActivo.email);
end;

procedure MostrarMenuUsuario(const usuario: TUsuario);
var
  window, vbox, btnBandeja, btnRedactar, btnGraficos: PGtkWidget;
begin
  UsuarioActivo := usuario;

  window := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(window), PChar('Menú Usuario - ' + usuario.email));
  gtk_window_set_default_size(GTK_WINDOW(window), 300, 200);

  vbox := gtk_vbox_new(FALSE, 10);
  gtk_container_add(GTK_CONTAINER(window), vbox);

  // Botón: Bandeja
  btnBandeja := gtk_button_new_with_label('📥 Bandeja de entrada');
  g_signal_connect(btnBandeja, 'clicked', G_CALLBACK(@OnBandejaClicked), nil);
  gtk_box_pack_start(GTK_BOX(vbox), btnBandeja, FALSE, FALSE, 10);

  // Botón: Redactar
  btnRedactar := gtk_button_new_with_label('✉️ Redactar correo');
  g_signal_connect(btnRedactar, 'clicked', G_CALLBACK(@OnRedactarClicked), nil);
  gtk_box_pack_start(GTK_BOX(vbox), btnRedactar, FALSE, FALSE, 10);

  // Botón: Generar Gráficos
  btnGraficos := gtk_button_new_with_label('📊 Generar Gráficos');
  g_signal_connect(btnGraficos, 'clicked', G_CALLBACK(@OnGenerarGraficosClicked), nil);
  gtk_box_pack_start(GTK_BOX(vbox), btnGraficos, FALSE, FALSE, 10);

  gtk_widget_show_all(window);
end;

end.
