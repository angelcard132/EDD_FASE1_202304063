unit reports;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, cola2;

// Genera un archivo DOT con los correos recibidos para emailDestino
procedure GenerarGraficoBandeja(const emailDestino: String; var programados: TCola; const rutaDot: String);

implementation

function NormalizarEmail(const s: String): String;
var
  i: Integer;
  c: Char;
  lower: String;
begin
  lower := LowerCase(s);
  Result := '';
  for i := 1 to Length(lower) do
  begin
    c := lower[i];
    if (c = '–') or (c = '—') or (c = '−') or (c = '‑') then c := '-';
    if ((c >= 'a') and (c <= 'z')) or ((c >= '0') and (c <= '9')) or (c = '@') or (c = '.') or (c = '_') or (c = '-') then
      Result := Result + c;
  end;
end;

function SanearTexto(const s: String): String;
var
  i: Integer;
  c: Char;
begin
  Result := '';
  for i := 1 to Length(s) do
  begin
    c := s[i];
    if (Ord(c) >= 32) and (Ord(c) <= 126) then
      Result := Result + c
    else
      Result := Result + '?';
  end;
end;

procedure GenerarGraficoBandeja(const emailDestino: String; var programados: TCola; const rutaDot: String);
var
  f: Text;
  actual: PCorreo;
  emailDestinoNorm, destNorm: String;
  idx: Integer;
begin
  AssignFile(f, rutaDot);
  Rewrite(f);
  try
    WriteLn(f, 'digraph Bandeja {');
    WriteLn(f, '  rankdir=LR;');
    WriteLn(f, '  node [shape=box, style=filled, color="#4F81BD", fontname="Helvetica", fontsize=10, fillcolor="#DCE6F1"];');
    WriteLn(f, '  label="Bandeja de entrada de ' + SanearTexto(emailDestino) + '"; labelloc=t; fontsize=16;');

    emailDestinoNorm := NormalizarEmail(emailDestino);
    idx := 0;
    actual := programados.frente;
    while actual <> nil do
    begin
      destNorm := NormalizarEmail(String(actual^.destinatario));
      if destNorm = emailDestinoNorm then
      begin
        Inc(idx);
        WriteLn(f, Format('  correo_%d [label="ID: %d\nDe: %s\nAsunto: %s"];',
                 [idx, actual^.id, SanearTexto(String(actual^.remitente)), SanearTexto(String(actual^.asunto))]));
        if idx > 1 then
          WriteLn(f, Format('  correo_%d -> correo_%d;', [idx-1, idx]));
      end;
      actual := actual^.siguiente;
    end;

    if idx = 0 then
      WriteLn(f, '  vacio [label="Sin correos recibidos", fillcolor="#F2F2F2", color="#BFBFBF"];');

    WriteLn(f, '}');
  finally
    CloseFile(f);
  end;
end;

end.
