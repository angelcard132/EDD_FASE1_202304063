unit menuusuario;

{$mode objfpc}{$H+}

interface

uses
  glib2, gtk2, gdk2, SysUtils,
  listasimple2, cola2, arbol_avl, arbol_b, json_loader;

procedure MostrarMenuUsuario(const email: String; var usuarios: TListaSimple; var programados: TCola; var borradores: PCorreoAVL; var favoritos: PNodoB);

implementation

uses
  redactar2, bandeja_entrada, login, programados, nuevo_contacto, perfil, comunidad, borradores, favoritos, eliminar, pila2;

var
  GEmail: String;
  GUsuarios: ^TListaSimple = nil;
  GProgramados: ^TCola = nil;
  GBorradores: ^PCorreoAVL = nil;
  GFavoritos: ^PNodoB = nil;
  GPapelera: TPila;

procedure OnRedactarCorreo(widget: PGtkWidget; data: gpointer); cdecl;
begin
  MostrarRedactarCorreo(GEmail, GUsuarios^, GProgramados^, GBorradores^, GFavoritos^);
end;

procedure OnCerrarSesionUsuario(widget: PGtkWidget; data: gpointer); cdecl;
var
  ventanaActual: PGtkWidget;
begin
  WriteLn('🔓 Cerrando sesión de usuario...');
  
  // Verificar que tenemos las estructuras necesarias
  if (GUsuarios <> nil) and (GProgramados <> nil) and (GBorradores <> nil) and (GFavoritos <> nil) then
  begin
    WriteLn('🔄 Mostrando login...');
    
    // Obtener y destruir la ventana actual ANTES de mostrar login
    if Assigned(widget) then
    begin
      ventanaActual := gtk_widget_get_toplevel(widget);
      if Assigned(ventanaActual) then
      begin
        WriteLn('✅ Destruyendo ventana de menú de usuario');
        gtk_widget_destroy(ventanaActual);
      end;
    end;
    
    // Limpiar referencias globales
    GEmail := '';
    
    // Procesar eventos pendientes para asegurar limpieza
    while gtk_events_pending() > 0 do
      gtk_main_iteration();
    
    // Mostrar el login después de limpiar
    MostrarLogin(GUsuarios^, GProgramados^, GBorradores^, GFavoritos^);
  end
  else
  begin
    WriteLn('❌ Error: Estructuras no disponibles');
    gtk_main_quit();
  end;
end;

function OnDeleteEventUsuario(widget: PGtkWidget; event: PGdkEvent; data: gpointer): gboolean; cdecl;
begin
  WriteLn('🔓 Cerrando ventana de usuario...');
  OnCerrarSesionUsuario(widget, data);
  Result := True; // Prevenir el cierre automático de la ventana
end;

procedure OnBandejaEntrada(widget: PGtkWidget; data: gpointer); cdecl;
begin
  MostrarBandejaEntrada(GEmail, GUsuarios^, GProgramados^, GBorradores^, GFavoritos^);
end;

procedure OnVerProgramados(widget: PGtkWidget; data: gpointer); cdecl;
begin
  MostrarProgramados(GEmail, GUsuarios^, GProgramados^, GBorradores^, GFavoritos^);
end;

procedure OnGestionContactos(widget: PGtkWidget; data: gpointer); cdecl;
begin
  MostrarGestionContactos(GEmail, GUsuarios^, GProgramados^, GBorradores^, GFavoritos^);
end;

procedure OnPerfil(widget: PGtkWidget; data: gpointer); cdecl;
begin
  MostrarPerfil(GEmail, GUsuarios^, GProgramados^, GBorradores^, GFavoritos^);
end;

procedure OnComunidades(widget: PGtkWidget; data: gpointer); cdecl;
begin
  MostrarMisComunidades(GEmail, GUsuarios^, GProgramados^, GBorradores^, GFavoritos^);
end;

procedure OnBorradores(widget: PGtkWidget; data: gpointer); cdecl;
begin
  MostrarGestorBorradores(GEmail, GBorradores^, GProgramados^);
end;

procedure OnFavoritos(widget: PGtkWidget; data: gpointer); cdecl;
begin
  MostrarGestorFavoritos(GEmail, GFavoritos^, GProgramados^);
end;

procedure OnPapelera(widget: PGtkWidget; data: gpointer); cdecl;
begin
  MostrarPapelera(GEmail, GPapelera);
end;

procedure MostrarMenuUsuario(const email: String; var usuarios: TListaSimple; var programados: TCola; var borradores: PCorreoAVL; var favoritos: PNodoB);
var
  w, vbox, lbl, btnBandeja, btnRedactar, btnBorr, btnFav, btnPapelera, btnProg, btnContactos, btnPerfil, btnComunidades, btnSalir: PGtkWidget;
  nombre: String;
begin
  // Guardar referencias globales
  GEmail := email;
  GUsuarios := @usuarios;
  GProgramados := @programados;
  GBorradores := @borradores;
  GFavoritos := @favoritos;
  
  // Inicializar papelera
  InicializarPila(GPapelera);
  
  nombre := NombreDeEmail(email);
  w := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(w), PChar('👤 Menú de Usuario - ' + nombre));
  gtk_window_set_default_size(GTK_WINDOW(w), 480, 380);
  gtk_window_set_position(GTK_WINDOW(w), GTK_WIN_POS_CENTER);
  gtk_container_set_border_width(GTK_CONTAINER(w), 16);

  // Conectar delete-event para que regrese al login en lugar de cerrar la aplicación
  g_signal_connect(w, 'delete-event', G_CALLBACK(@OnDeleteEventUsuario), nil);

  vbox := gtk_vbox_new(False, 12);
  gtk_container_add(GTK_CONTAINER(w), vbox);

  lbl := gtk_label_new(PChar('Bienvenido, ' + nombre + ' (' + email + ')'));
  gtk_box_pack_start(GTK_BOX(vbox), lbl, False, False, 10);

  // Botón Bandeja de Entrada
  btnBandeja := gtk_button_new_with_label('📥 Bandeja de Entrada');
  g_signal_connect(btnBandeja, 'clicked', G_CALLBACK(@OnBandejaEntrada), nil);
  gtk_box_pack_start(GTK_BOX(vbox), btnBandeja, True, True, 5);

  // Botón Redactar Correo
  btnRedactar := gtk_button_new_with_label('✉️ Redactar Correo');
  g_signal_connect(btnRedactar, 'clicked', G_CALLBACK(@OnRedactarCorreo), nil);
  gtk_box_pack_start(GTK_BOX(vbox), btnRedactar, True, True, 5);

  // Botón Gestión de Contactos
  btnContactos := gtk_button_new_with_label('👥 Agregar Contacto');
  g_signal_connect(btnContactos, 'clicked', G_CALLBACK(@OnGestionContactos), nil);
  gtk_box_pack_start(GTK_BOX(vbox), btnContactos, True, True, 5);

  // Botón Perfil
  btnPerfil := gtk_button_new_with_label('👤 Mi Perfil');
  g_signal_connect(btnPerfil, 'clicked', G_CALLBACK(@OnPerfil), nil);
  gtk_box_pack_start(GTK_BOX(vbox), btnPerfil, True, True, 5);

  // Botón Comunidades (NUEVO)
  btnComunidades := gtk_button_new_with_label('🏘️ Comunidades');
  g_signal_connect(btnComunidades, 'clicked', G_CALLBACK(@OnComunidades), nil);
  gtk_box_pack_start(GTK_BOX(vbox), btnComunidades, True, True, 5);

  btnProg := gtk_button_new_with_label('📋 Ver Programados (Cola)');
  g_signal_connect(btnProg, 'clicked', G_CALLBACK(@OnVerProgramados), nil);
  gtk_box_pack_start(GTK_BOX(vbox), btnProg, True, True, 5);

  btnBorr := gtk_button_new_with_label('📝 Ver Borradores (AVL)');
  g_signal_connect(btnBorr, 'clicked', G_CALLBACK(@OnBorradores), nil);
  gtk_box_pack_start(GTK_BOX(vbox), btnBorr, True, True, 5);

  btnFav := gtk_button_new_with_label('⭐ Ver Favoritos (B-Tree)');
  g_signal_connect(btnFav, 'clicked', G_CALLBACK(@OnFavoritos), nil);
  gtk_box_pack_start(GTK_BOX(vbox), btnFav, True, True, 5);

  btnPapelera := gtk_button_new_with_label('🗑️ Ver Papelera (Pila)');
  g_signal_connect(btnPapelera, 'clicked', G_CALLBACK(@OnPapelera), nil);
  gtk_box_pack_start(GTK_BOX(vbox), btnPapelera, True, True, 5);

  btnSalir := gtk_button_new_with_label('🚪 Cerrar sesión');
  g_signal_connect(btnSalir, 'clicked', G_CALLBACK(@OnCerrarSesionUsuario), nil);
  gtk_box_pack_start(GTK_BOX(vbox), btnSalir, True, True, 5);

  WriteLn('👤 Mostrando menú de usuario para: ', email);
  gtk_widget_show_all(w);
end;

end.
