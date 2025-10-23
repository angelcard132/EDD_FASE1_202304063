unit menuusuario;

{$mode objfpc}{$H+}

interface

uses
  glib2, gtk2, gdk2, SysUtils,
  listasimple2, cola2, arbol_avl, arbol_b, blockchain, pila2, control_login, merkle_tree,
  redactar2, borradores, favoritos, bandeja_entrada, programados, eliminar, registro_usuario, reports, comunidad, nuevo_contacto, perfil, correos_privados; // ✅ AGREGAR merkle_tree y correos_privados

procedure MostrarMenuUsuario(const emailUsuario: String; var usuarios: TListaSimple; var programados: TCola; var borradores: PCorreoAVL; var favoritos: PNodoB; var blockchainMail: TBlockchain; var papelera: TPila; var merklePrivados: TArbolMerkle); // ✅ AGREGAR merklePrivados

implementation

uses
  login; // ✅ AGREGAR uses login aquí para evitar referencia circular

var
  GEmailUsuario: String;
  GUsuarios: ^TListaSimple = nil;
  GProgramados: ^TCola = nil;
  GBorradores: ^PCorreoAVL = nil;
  GFavoritos: ^PNodoB = nil;
  GBlockchain: ^TBlockchain = nil;
  GPapelera: ^TPila = nil;
  GMerklePrivados: ^TArbolMerkle = nil; // ✅ NUEVA: referencia al árbol de Merkle

  MenuWindow: PGtkWidget = nil;

procedure OnCerrarSesion(widget: PGtkWidget; data: gpointer); cdecl;
begin
  WriteLn('👋 Cerrando sesión de usuario: ', GEmailUsuario);
  
  // ✅ REGISTRAR SALIDA DEL USUARIO
  RegistrarSalida(GEmailUsuario);
  
  // ✅ CERRAR ventana actual sin terminar la aplicación
  if Assigned(MenuWindow) then
  begin
    WriteLn('🔧 DEBUG: Cerrando ventana usuario...');
    gtk_widget_destroy(MenuWindow);
    MenuWindow := nil; // ✅ RESETEAR para evitar referencias
  end;
  
  // ✅ VOLVER AL LOGIN SIN TERMINAR LA APLICACIÓN
  WriteLn('🔧 DEBUG: Regresando al login desde usuario...');
  if (GUsuarios <> nil) and (GProgramados <> nil) and (GBorradores <> nil) and (GFavoritos <> nil) and (GBlockchain <> nil) then
    MostrarLogin(GUsuarios^, GProgramados^, GBorradores^, GFavoritos^, GBlockchain^);
end;

procedure OnRedactar(widget: PGtkWidget; data: gpointer); cdecl;
begin
  if (GUsuarios <> nil) and (GProgramados <> nil) and (GBorradores <> nil) and (GFavoritos <> nil) and (GBlockchain <> nil) then
    MostrarRedactarCorreo(GEmailUsuario, GUsuarios^, GProgramados^, GBorradores^, GFavoritos^, GBlockchain^);
end;

procedure OnBandeja(widget: PGtkWidget; data: gpointer); cdecl;
begin
  if (GUsuarios <> nil) and (GProgramados <> nil) and (GBorradores <> nil) and (GFavoritos <> nil) and (GBlockchain <> nil) and (GPapelera <> nil) and (GMerklePrivados <> nil) then
    MostrarBandejaEntrada(GEmailUsuario, GUsuarios^, GProgramados^, GBorradores^, GFavoritos^, GPapelera^, GBlockchain^, GMerklePrivados^); // ✅ AGREGAR GMerklePrivados^
end;

procedure OnBorradores(widget: PGtkWidget; data: gpointer); cdecl;
begin
  if (GBorradores <> nil) and (GProgramados <> nil) and (GBlockchain <> nil) and (GPapelera <> nil) then
    MostrarGestorBorradores(GEmailUsuario, GBorradores^, GProgramados^, GBlockchain^, GPapelera^);
end;

procedure OnFavoritos(widget: PGtkWidget; data: gpointer); cdecl;
begin
  if (GFavoritos <> nil) and (GProgramados <> nil) then
    MostrarGestorFavoritos(GEmailUsuario, GFavoritos^, GProgramados^);
end;

procedure OnProgramados(widget: PGtkWidget; data: gpointer); cdecl;
begin
  if (GUsuarios <> nil) and (GProgramados <> nil) and (GBorradores <> nil) and (GFavoritos <> nil) and (GBlockchain <> nil) then
    MostrarProgramados(GEmailUsuario, GUsuarios^, GProgramados^, GBorradores^, GFavoritos^, GBlockchain^);
end;

procedure OnPapelera(widget: PGtkWidget; data: gpointer); cdecl;
begin
  if GPapelera <> nil then
    MostrarPapelera(GEmailUsuario, GPapelera^);
end;

procedure OnReportes(widget: PGtkWidget; data: gpointer); cdecl;
begin
  // ✅ ACTUALIZAR: Incluir merkle tree en reportes
  if (GUsuarios <> nil) and (GProgramados <> nil) and (GBorradores <> nil) and (GFavoritos <> nil) and (GPapelera <> nil) and (GBlockchain <> nil) and (GMerklePrivados <> nil) then
    GenerarReportesCompletos(GEmailUsuario, GUsuarios^, GProgramados^, GBorradores^, GFavoritos^, GPapelera^, GBlockchain^, GMerklePrivados^)
  else
    WriteLn('❌ Error: Alguna estructura no está inicializada para generar reportes');
end;

procedure OnComunidades(widget: PGtkWidget; data: gpointer); cdecl;
begin
  if (GUsuarios <> nil) and (GProgramados <> nil) and (GBorradores <> nil) and (GFavoritos <> nil) then
    MostrarMisComunidades(GEmailUsuario, GUsuarios^, GProgramados^, GBorradores^, GFavoritos^);
end;

procedure OnRegistrarUsuario(widget: PGtkWidget; data: gpointer); cdecl;
begin
  if (GUsuarios <> nil) and (GProgramados <> nil) and (GBorradores <> nil) and (GFavoritos <> nil) then
    MostrarGestionContactos(GEmailUsuario, GUsuarios^, GProgramados^, GBorradores^, GFavoritos^); // ✅ CAMBIAR A GESTIÓN DE CONTACTOS
end;

procedure OnMiPerfil(widget: PGtkWidget; data: gpointer); cdecl;
begin
  if (GUsuarios <> nil) and (GProgramados <> nil) and (GBorradores <> nil) and (GFavoritos <> nil) then
    MostrarPerfil(GEmailUsuario, GUsuarios^, GProgramados^, GBorradores^, GFavoritos^);
end;

procedure OnCorreosPrivados(widget: PGtkWidget; data: gpointer); cdecl;
begin
  if (GUsuarios <> nil) and (GProgramados <> nil) and (GBorradores <> nil) and (GFavoritos <> nil) and (GMerklePrivados <> nil) then
    MostrarCorreosPrivados(GEmailUsuario, GUsuarios^, GProgramados^, GBorradores^, GFavoritos^, GMerklePrivados^);
end;

procedure MostrarMenuUsuario(const emailUsuario: String; var usuarios: TListaSimple; var programados: TCola; var borradores: PCorreoAVL; var favoritos: PNodoB; var blockchainMail: TBlockchain; var papelera: TPila; var merklePrivados: TArbolMerkle); // ✅ AGREGAR merklePrivados
var
  vbox, gridBox: PGtkWidget;
  lblTitulo, lblUsuario: PGtkWidget;
  btnRedactar, btnBandeja, btnBorradores, btnFavoritos, btnProgramados, btnPapelera, btnReportes, btnComunidades, btnContactos, btnPerfil, btnPrivados, btnCerrar: PGtkWidget; // ✅ AGREGAR btnPrivados
begin
  WriteLn('🔧 DEBUG: Iniciando MostrarMenuUsuario para: ', emailUsuario);
  
  // Guardar referencias globales
  GEmailUsuario := emailUsuario;
  GUsuarios := @usuarios;
  GProgramados := @programados;
  GBorradores := @borradores;
  GFavoritos := @favoritos;
  GBlockchain := @blockchainMail;
  GPapelera := @papelera;
  GMerklePrivados := @merklePrivados; // ✅ NUEVA: guardar referencia al Merkle Tree

  if Assigned(MenuWindow) then
    gtk_widget_destroy(MenuWindow);

  MenuWindow := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(MenuWindow), PChar('EDDMail - ' + emailUsuario));
  gtk_window_set_default_size(GTK_WINDOW(MenuWindow), 400, 600); // ✅ AUMENTAR ALTURA para nuevo botón
  gtk_window_set_position(GTK_WINDOW(MenuWindow), GTK_WIN_POS_CENTER);
  gtk_container_set_border_width(GTK_CONTAINER(MenuWindow), 20);

  // ✅ CONECTAR EVENTO DELETE PARA NO TERMINAR LA APLICACIÓN - IGUAL COMPORTAMIENTO QUE CERRAR SESIÓN
  g_signal_connect(MenuWindow, 'delete-event', G_CALLBACK(@gtk_widget_hide_on_delete), nil);
  g_signal_connect(MenuWindow, 'destroy', G_CALLBACK(@OnCerrarSesion), nil);

  vbox := gtk_vbox_new(False, 15);
  gtk_container_add(GTK_CONTAINER(MenuWindow), vbox);

  lblTitulo := gtk_label_new('📧 Sistema de Correos EDDMail');
  gtk_box_pack_start(GTK_BOX(vbox), lblTitulo, False, False, 0);

  lblUsuario := gtk_label_new(PChar('👤 Usuario: ' + emailUsuario));
  gtk_box_pack_start(GTK_BOX(vbox), lblUsuario, False, False, 0);

  gridBox := gtk_vbox_new(False, 10);
  gtk_box_pack_start(GTK_BOX(vbox), gridBox, True, True, 0);

  // Botones principales
  btnRedactar := gtk_button_new_with_label('✍️ Redactar Correo');
  g_signal_connect(btnRedactar, 'clicked', G_CALLBACK(@OnRedactar), nil);
  gtk_box_pack_start(GTK_BOX(gridBox), btnRedactar, True, True, 0);

  btnBandeja := gtk_button_new_with_label('📥 Bandeja de Entrada');
  g_signal_connect(btnBandeja, 'clicked', G_CALLBACK(@OnBandeja), nil);
  gtk_box_pack_start(GTK_BOX(gridBox), btnBandeja, True, True, 0);

  btnBorradores := gtk_button_new_with_label('📝 Borradores');
  g_signal_connect(btnBorradores, 'clicked', G_CALLBACK(@OnBorradores), nil);
  gtk_box_pack_start(GTK_BOX(gridBox), btnBorradores, True, True, 0);

  btnFavoritos := gtk_button_new_with_label('⭐ Favoritos');
  g_signal_connect(btnFavoritos, 'clicked', G_CALLBACK(@OnFavoritos), nil);
  gtk_box_pack_start(GTK_BOX(gridBox), btnFavoritos, True, True, 0);

  // ✅ NUEVO: BOTÓN CORREOS PRIVADOS
  btnPrivados := gtk_button_new_with_label('🔒 Correos Privados');
  g_signal_connect(btnPrivados, 'clicked', G_CALLBACK(@OnCorreosPrivados), nil);
  gtk_box_pack_start(GTK_BOX(gridBox), btnPrivados, True, True, 0);

  btnProgramados := gtk_button_new_with_label('📅 Programados');
  g_signal_connect(btnProgramados, 'clicked', G_CALLBACK(@OnProgramados), nil);
  gtk_box_pack_start(GTK_BOX(gridBox), btnProgramados, True, True, 0);

  btnPapelera := gtk_button_new_with_label('🗑️ Papelera');
  g_signal_connect(btnPapelera, 'clicked', G_CALLBACK(@OnPapelera), nil);
  gtk_box_pack_start(GTK_BOX(gridBox), btnPapelera, True, True, 0);

  btnReportes := gtk_button_new_with_label('📊 Reportes');
  g_signal_connect(btnReportes, 'clicked', G_CALLBACK(@OnReportes), nil);
  gtk_box_pack_start(GTK_BOX(gridBox), btnReportes, True, True, 0);

  btnComunidades := gtk_button_new_with_label('🏘️ Comunidades');
  g_signal_connect(btnComunidades, 'clicked', G_CALLBACK(@OnComunidades), nil);
  gtk_box_pack_start(GTK_BOX(gridBox), btnComunidades, True, True, 0);

  btnContactos := gtk_button_new_with_label('👥 Mis Contactos');
  g_signal_connect(btnContactos, 'clicked', G_CALLBACK(@OnRegistrarUsuario), nil);
  gtk_box_pack_start(GTK_BOX(gridBox), btnContactos, True, True, 0);

  btnPerfil := gtk_button_new_with_label('👤 Mi Perfil');
  g_signal_connect(btnPerfil, 'clicked', G_CALLBACK(@OnMiPerfil), nil);
  gtk_box_pack_start(GTK_BOX(gridBox), btnPerfil, True, True, 0);

  btnCerrar := gtk_button_new_with_label('🚪 Cerrar Sesión');
  g_signal_connect(btnCerrar, 'clicked', G_CALLBACK(@OnCerrarSesion), nil);
  gtk_box_pack_start(GTK_BOX(gridBox), btnCerrar, True, True, 0);

  WriteLn('🔧 DEBUG: Mostrando ventana usuario...');
  gtk_widget_show_all(MenuWindow);
  WriteLn('✅ Menú usuario mostrado exitosamente para: ', emailUsuario);
end;

end.
