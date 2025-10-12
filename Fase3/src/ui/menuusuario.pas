unit menuusuario;

{$mode objfpc}{$H+}

interface

uses
  glib2, gtk2, gdk2, SysUtils,
  listasimple2, cola2, arbol_avl, arbol_b, blockchain,
  bandeja_entrada, redactar2, borradores, favoritos, eliminar, programados, 
  comunidad, reports, registro_usuario, pila2, control_login; // ✅ AGREGAR control_login

procedure MostrarMenuUsuario(const emailUsuario: String; var usuarios: TListaSimple; var programados: TCola; var borradores: PCorreoAVL; var favoritos: PNodoB; var papelera: TPila; var blockchainMail: TBlockchain);

implementation

uses
  login;

var
  GEmailUsuario: String;
  GUsuarios: ^TListaSimple = nil;
  GProgramados: ^TCola = nil;
  GBorradores: ^PCorreoAVL = nil;
  GFavoritos: ^PNodoB = nil;
  GPapelera: ^TPila = nil;
  GBlockchain: ^TBlockchain = nil;

procedure OnBandejaEntrada(widget: PGtkWidget; data: gpointer); cdecl;
begin
  if (GUsuarios <> nil) and (GProgramados <> nil) and (GBorradores <> nil) and (GFavoritos <> nil) and (GPapelera <> nil) and (GBlockchain <> nil) then
    MostrarBandejaEntrada(GEmailUsuario, GUsuarios^, GProgramados^, GBorradores^, GFavoritos^, GPapelera^, GBlockchain^);
end;

procedure OnRedactarCorreo(widget: PGtkWidget; data: gpointer); cdecl;
begin
  if (GUsuarios <> nil) and (GProgramados <> nil) and (GBorradores <> nil) and (GFavoritos <> nil) and (GBlockchain <> nil) then
    MostrarRedactarCorreo(GEmailUsuario, GUsuarios^, GProgramados^, GBorradores^, GFavoritos^, GBlockchain^);
end;

procedure OnGestorBorradores(widget: PGtkWidget; data: gpointer); cdecl;
begin
  if (GBorradores <> nil) and (GProgramados <> nil) and (GBlockchain <> nil) then
    MostrarGestorBorradores(GEmailUsuario, GBorradores^, GProgramados^, GBlockchain^);
end;

procedure OnGestorFavoritos(widget: PGtkWidget; data: gpointer); cdecl;
begin
  if (GFavoritos <> nil) and (GProgramados <> nil) then
    MostrarGestorFavoritos(GEmailUsuario, GFavoritos^, GProgramados^);
end;

procedure OnPapelera(widget: PGtkWidget; data: gpointer); cdecl;
begin
  WriteLn('🔍 DEBUG: Accediendo a papelera - GPapelera: ', Assigned(GPapelera));
  
  if GPapelera <> nil then
  begin
    WriteLn('🔍 DEBUG: GPapelera asignada - Tope: ', Assigned(GPapelera^.tope));
    
    // ✅ VALIDACIÓN SEGURA antes de contar
    try
      WriteLn('🔍 DEBUG: Intentando contar elementos...');
      WriteLn('🔍 DEBUG: Elementos en papelera: ', ContarCorreos(GPapelera^));
      MostrarPapelera(GEmailUsuario, GPapelera^);
    except
      on E: Exception do
      begin
        WriteLn('❌ ERROR CRÍTICO en papelera: ', E.Message);
        WriteLn('🔧 Inicializando papelera desde cero...');
        InicializarPila(GPapelera^);
        MostrarPapelera(GEmailUsuario, GPapelera^);
      end;
    end;
  end
  else
  begin
    WriteLn('❌ ERROR: GPapelera es nil');
  end;
end;

procedure OnCorreosProgramados(widget: PGtkWidget; data: gpointer); cdecl;
begin
  if (GUsuarios <> nil) and (GProgramados <> nil) and (GBorradores <> nil) and (GFavoritos <> nil) and (GBlockchain <> nil) then
    MostrarProgramados(GEmailUsuario, GUsuarios^, GProgramados^, GBorradores^, GFavoritos^, GBlockchain^);
end;

procedure OnMisComunidades(widget: PGtkWidget; data: gpointer); cdecl;
begin
  if (GUsuarios <> nil) and (GProgramados <> nil) and (GBorradores <> nil) and (GFavoritos <> nil) then
    MostrarMisComunidades(GEmailUsuario, GUsuarios^, GProgramados^, GBorradores^, GFavoritos^);
end;

procedure OnAgregarContacto(widget: PGtkWidget; data: gpointer); cdecl;
begin
  if (GUsuarios <> nil) and (GProgramados <> nil) and (GBorradores <> nil) and (GFavoritos <> nil) then
    MostrarRegistroUsuario(GUsuarios^, GProgramados^, GBorradores^, GFavoritos^);
end;

procedure OnGenerarReportes(widget: PGtkWidget; data: gpointer); cdecl;
begin
  if (GUsuarios <> nil) and (GProgramados <> nil) and (GBorradores <> nil) and (GFavoritos <> nil) and (GPapelera <> nil) then
  begin
    WriteLn('📊 Generando reportes completos para: ', GEmailUsuario);
    GenerarReportesCompletos(GEmailUsuario, GUsuarios^, GProgramados^, GBorradores^, GFavoritos^, GPapelera^);
  end;
end;

procedure OnVerBlockchain(widget: PGtkWidget; data: gpointer); cdecl;
var
  dialog: PGtkWidget;
begin
  if GBlockchain <> nil then
  begin
    WriteLn('🔗 BLOCKCHAIN EDD-MAIL');
    WriteLn('=====================');
    MostrarBlockchain(GBlockchain^);
    
    dialog := gtk_message_dialog_new(nil,
      GTK_DIALOG_MODAL,
      GTK_MESSAGE_INFO,
      GTK_BUTTONS_OK,
      PChar('🔗 Blockchain mostrada en consola' + #10 + #10 +
            'Total de bloques: ' + IntToStr(ContarBloquesBlockchain(GBlockchain^)) + #10 +
            'Revisa la consola para ver la estructura completa.'));
    gtk_dialog_run(GTK_DIALOG(dialog));
    gtk_widget_destroy(dialog);
  end;
end;

procedure OnCerrarSesion(widget: PGtkWidget; data: gpointer); cdecl;
begin
  WriteLn('👋 Cerrando sesión de: ', GEmailUsuario);
  
  // ✅ REGISTRAR SALIDA DEL USUARIO
  RegistrarSalida(GEmailUsuario);
  
  // Cerrar ventana actual
  if Assigned(widget) then
    gtk_widget_destroy(gtk_widget_get_toplevel(widget));
  
  // Regresar al login principal
  if (GUsuarios <> nil) and (GProgramados <> nil) and (GBorradores <> nil) and (GFavoritos <> nil) and (GBlockchain <> nil) then
    MostrarLogin(GUsuarios^, GProgramados^, GBorradores^, GFavoritos^, GBlockchain^);
end;

procedure MostrarMenuUsuario(const emailUsuario: String; var usuarios: TListaSimple; var programados: TCola; var borradores: PCorreoAVL; var favoritos: PNodoB; var papelera: TPila; var blockchainMail: TBlockchain);
var
  window: PGtkWidget;
  vbox, gridBox: PGtkWidget;
  lblTitulo, lblUsuario: PGtkWidget;
  btnBandeja, btnRedactar, btnBorradores, btnFavoritos: PGtkWidget;
  btnPapelera, btnProgramados, btnComunidades, btnContactos: PGtkWidget;
  btnReportes, btnBlockchain, btnCerrar: PGtkWidget;
begin
  GEmailUsuario := emailUsuario;
  GUsuarios := @usuarios;
  GProgramados := @programados;
  GBorradores := @borradores;
  GFavoritos := @favoritos;
  GPapelera := @papelera;
  GBlockchain := @blockchainMail;
  
  // ✅ VERIFICAR E INICIALIZAR PAPELERA
  if GPapelera <> nil then
  begin
    WriteLn('🔍 DEBUG: Verificando inicialización de papelera...');
    if GPapelera^.tope = nil then
    begin
      WriteLn('🔧 DEBUG: Inicializando papelera vacía...');
      InicializarPila(GPapelera^);
    end;
    WriteLn('✅ DEBUG: Papelera lista. Elementos: ', ContarCorreos(GPapelera^));
  end;
  
  WriteLn('🏠 Mostrando menú principal para usuario: ', emailUsuario);
  
  // Crear ventana principal
  window := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(window), PChar('📧 EDDMail con Blockchain - ' + emailUsuario));
  gtk_window_set_default_size(GTK_WINDOW(window), 600, 500);
  gtk_window_set_position(GTK_WINDOW(window), GTK_WIN_POS_CENTER);
  gtk_container_set_border_width(GTK_CONTAINER(window), 20);

  // Conectar evento de cierre
  g_signal_connect(window, 'destroy', G_CALLBACK(@OnCerrarSesion), nil);

  // Container principal
  vbox := gtk_vbox_new(False, 20);
  gtk_container_add(GTK_CONTAINER(window), vbox);

  // Título y usuario
  lblTitulo := gtk_label_new('📧 Sistema de Correos EDD-Mail con Blockchain');
  gtk_box_pack_start(GTK_BOX(vbox), lblTitulo, False, False, 0);

  lblUsuario := gtk_label_new(PChar('👤 Bienvenido: ' + emailUsuario));
  gtk_box_pack_start(GTK_BOX(vbox), lblUsuario, False, False, 0);

  // Grid de botones principales (3x4)
  gridBox := gtk_table_new(4, 3, True);
  gtk_table_set_homogeneous(GTK_TABLE(gridBox), True);
  gtk_table_set_row_spacings(GTK_TABLE(gridBox), 10);
  gtk_table_set_col_spacings(GTK_TABLE(gridBox), 10);
  gtk_box_pack_start(GTK_BOX(vbox), gridBox, True, True, 0);

  // Fila 1 - Funciones principales
  btnBandeja := gtk_button_new_with_label('📥 Bandeja de Entrada');
  gtk_widget_set_size_request(btnBandeja, 180, 60);
  g_signal_connect(btnBandeja, 'clicked', G_CALLBACK(@OnBandejaEntrada), nil);
  gtk_table_attach_defaults(GTK_TABLE(gridBox), btnBandeja, 0, 1, 0, 1);

  btnRedactar := gtk_button_new_with_label('✉️ Redactar Correo');
  gtk_widget_set_size_request(btnRedactar, 180, 60);
  g_signal_connect(btnRedactar, 'clicked', G_CALLBACK(@OnRedactarCorreo), nil);
  gtk_table_attach_defaults(GTK_TABLE(gridBox), btnRedactar, 1, 2, 0, 1);

  btnProgramados := gtk_button_new_with_label('📅 Correos Programados');
  gtk_widget_set_size_request(btnProgramados, 180, 60);
  g_signal_connect(btnProgramados, 'clicked', G_CALLBACK(@OnCorreosProgramados), nil);
  gtk_table_attach_defaults(GTK_TABLE(gridBox), btnProgramados, 2, 3, 0, 1);

  // Fila 2 - Gestión de correos
  btnBorradores := gtk_button_new_with_label('📝 Borradores');
  gtk_widget_set_size_request(btnBorradores, 180, 60);
  g_signal_connect(btnBorradores, 'clicked', G_CALLBACK(@OnGestorBorradores), nil);
  gtk_table_attach_defaults(GTK_TABLE(gridBox), btnBorradores, 0, 1, 1, 2);

  btnFavoritos := gtk_button_new_with_label('⭐ Favoritos');
  gtk_widget_set_size_request(btnFavoritos, 180, 60);
  g_signal_connect(btnFavoritos, 'clicked', G_CALLBACK(@OnGestorFavoritos), nil);
  gtk_table_attach_defaults(GTK_TABLE(gridBox), btnFavoritos, 1, 2, 1, 2);

  btnPapelera := gtk_button_new_with_label('🗑️ Papelera');
  gtk_widget_set_size_request(btnPapelera, 180, 60);
  g_signal_connect(btnPapelera, 'clicked', G_CALLBACK(@OnPapelera), nil);
  gtk_table_attach_defaults(GTK_TABLE(gridBox), btnPapelera, 2, 3, 1, 2);

  // Fila 3 - Funciones adicionales
  btnComunidades := gtk_button_new_with_label('🏘️ Mis Comunidades');
  gtk_widget_set_size_request(btnComunidades, 180, 60);
  g_signal_connect(btnComunidades, 'clicked', G_CALLBACK(@OnMisComunidades), nil);
  gtk_table_attach_defaults(GTK_TABLE(gridBox), btnComunidades, 0, 1, 2, 3);

  btnContactos := gtk_button_new_with_label('👥 Agregar Contacto');
  gtk_widget_set_size_request(btnContactos, 180, 60);
  g_signal_connect(btnContactos, 'clicked', G_CALLBACK(@OnAgregarContacto), nil);
  gtk_table_attach_defaults(GTK_TABLE(gridBox), btnContactos, 1, 2, 2, 3);

  btnReportes := gtk_button_new_with_label('📊 Generar Reportes');
  gtk_widget_set_size_request(btnReportes, 180, 60);
  g_signal_connect(btnReportes, 'clicked', G_CALLBACK(@OnGenerarReportes), nil);
  gtk_table_attach_defaults(GTK_TABLE(gridBox), btnReportes, 2, 3, 2, 3);

  // Fila 4 - Blockchain y salir
  btnBlockchain := gtk_button_new_with_label('🔗 Ver Blockchain');
  gtk_widget_set_size_request(btnBlockchain, 180, 60);
  g_signal_connect(btnBlockchain, 'clicked', G_CALLBACK(@OnVerBlockchain), nil);
  gtk_table_attach_defaults(GTK_TABLE(gridBox), btnBlockchain, 0, 1, 3, 4);

  btnCerrar := gtk_button_new_with_label('🚪 Cerrar Sesión');
  gtk_widget_set_size_request(btnCerrar, 180, 60);
  g_signal_connect(btnCerrar, 'clicked', G_CALLBACK(@OnCerrarSesion), nil);
  gtk_table_attach_defaults(GTK_TABLE(gridBox), btnCerrar, 1, 2, 3, 4);

  gtk_widget_show_all(window);
  
  WriteLn('✅ Menú usuario cargado exitosamente');
end;

end.
