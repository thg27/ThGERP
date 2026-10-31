-- =====================================================================
-- ThGERP (Gruppe FAKT) – App THG-FINANZ (20050)
-- 48 – Rechnungsversand per E-Mail (Microsoft Graph, Office 365):
--      FAKT_MAIL_VORLAGEN (MVOR): E-Mail-Vorlage je Mandant und Belegart (derzeit RECHNUNG) mit Betreff, Text (HTML)
--        und Bcc (EDV: office@thg-edv.com, HOLDING: office@gesslbauer.com). Platzhalter siehe FAKT_RECHNUNG_VERSAND.
--      Package FAKT_RECHNUNG_VERSAND:
--        vorbelegen – Absender (angemeldeter Mitarbeiter, MITA_EMAIL), Empfaenger (KUND_EMAIL_RECHNUNG bzw. E-Mail des
--          Ansprechpartners), Bcc, Betreff und Text aus der Vorlage, Anhang = zuletzt abgelegter Rechnungsdruck
--          (fehlt er, wird er jetzt erzeugt und abgelegt) – fuer die Vorschau (Dialog Seite 17)
--        senden – POST /users/{absender}/sendMail ueber das Web Credential entra-thgerp (Anwendungsberechtigung
--          Mail.Send), Kopie in den Gesendeten Elementen des Absenders; Status GEDRUCKT -> GESENDET (Historie
--          "Gesendet" per Trigger RECH_HIST_AIU) und Historie "E-Mail versendet" (An, Cc, Bcc, Betreff, Anhang)
-- Voraussetzung: 21, 24, 33, 35, 47; Web Credential entra-thgerp mit Mail.Send (Doku/anleitung-entra-id.md)
-- Erzeugt: 2026-10-31
-- Wiederholbar (DDL_UTIL; create or replace; Vorlagen nur anlegen, wenn noch keine da ist).
-- =====================================================================

set define off
set serveroutput on size unlimited

begin
    DDL_UTIL.tabelle('FAKT_MAIL_VORLAGEN', q'~create table FAKT_MAIL_VORLAGEN (
  MVOR_ID number not null,
  MVOR_MAND_ID number not null,
  MVOR_BELEGART varchar2(20 char) default 'RECHNUNG' not null,
  MVOR_BCC varchar2(1000 char),
  MVOR_BETREFF varchar2(500 char) not null,
  MVOR_TEXT clob not null,
  MVOR_CREATED_ON timestamp not null,
  MVOR_CREATED_BY varchar2(255 char) not null,
  MVOR_UPDATED_ON timestamp,
  MVOR_UPDATED_BY varchar2(255 char),
  MVOR_ROW_VERSION number not null,
  constraint MVOR_PK primary key (MVOR_ID)
)~');
    DDL_UTIL.constraint_('FAKT_MAIL_VORLAGEN', 'MVOR_UK', 'U', 'MVOR_MAND_ID, MVOR_BELEGART');
    DDL_UTIL.constraint_('FAKT_MAIL_VORLAGEN', 'MVOR_BELEGART_CK', 'C', q'~MVOR_BELEGART in ('RECHNUNG')~');
    DDL_UTIL.constraint_('FAKT_MAIL_VORLAGEN', 'MVOR_MAND_FK', 'R', 'MVOR_MAND_ID references ADMIN_MANDANTEN (MAND_ID)');
    DDL_UTIL.trigger_pruefen('MVOR_BIU', 'FAKT_MAIL_VORLAGEN');
end;
/

comment on table FAKT_MAIL_VORLAGEN is 'E-Mail-Vorlagen je Mandant und Belegart (Rechnungsversand über Microsoft Graph)';
comment on column FAKT_MAIL_VORLAGEN.MVOR_BCC is 'Blindkopie an (mehrere Adressen mit ; getrennt), z. B. office@thg-edv.com';
comment on column FAKT_MAIL_VORLAGEN.MVOR_BETREFF is 'Betreff mit Platzhaltern (#RECHNUNGSNUMMER# …)';
comment on column FAKT_MAIL_VORLAGEN.MVOR_TEXT is 'Text (HTML) mit Platzhaltern: #ANREDE# #RECHNUNGSNUMMER# #RECHNUNGSDATUM# #BETRAG# #FAELLIG_AM# #ZAHLUNGSHINWEIS# #KUNDE# #ABSENDER#';

create or replace trigger MVOR_BIU
  before insert or update on FAKT_MAIL_VORLAGEN
  for each row
begin
  if inserting then
    :new.MVOR_ID := coalesce(:new.MVOR_ID, to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'));
    :new.MVOR_CREATED_ON  := systimestamp;
    :new.MVOR_CREATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.MVOR_UPDATED_ON  := null;
    :new.MVOR_UPDATED_BY  := null;
    :new.MVOR_ROW_VERSION := 1;
  elsif updating then
    :new.MVOR_ID          := :old.MVOR_ID;  -- Primaerschluessel ist unveraenderlich
    :new.MVOR_CREATED_ON  := :old.MVOR_CREATED_ON;
    :new.MVOR_CREATED_BY  := :old.MVOR_CREATED_BY;
    :new.MVOR_UPDATED_ON  := systimestamp;
    :new.MVOR_UPDATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.MVOR_ROW_VERSION := nvl(:old.MVOR_ROW_VERSION, 0) + 1;
  end if;
  :new.MVOR_BCC := lower(regexp_replace(trim(:new.MVOR_BCC), '\s*[,;]\s*', '; '));
end MVOR_BIU;
/

-- Vorlagen je Mandant (nur anlegen, wenn noch keine da ist – Aenderungen bleiben bei erneuter Installation erhalten)
declare
    procedure vorlage(p_code in varchar2, p_bcc in varchar2, p_firma in varchar2, p_anschrift in varchar2,
                      p_kontakt in varchar2) is
    begin
        insert into FAKT_MAIL_VORLAGEN (MVOR_MAND_ID, MVOR_BELEGART, MVOR_BCC, MVOR_BETREFF, MVOR_TEXT)
        select m.MAND_ID, 'RECHNUNG', p_bcc, 'Rechnung #RECHNUNGSNUMMER# – ' || p_firma,
               '<p>#ANREDE#</p>'
               || '<p>anbei erhalten Sie unsere Rechnung <strong>#RECHNUNGSNUMMER#</strong> vom #RECHNUNGSDATUM# über '
               || '<strong>#BETRAG#</strong>.</p>'
               || '#ZAHLUNGSHINWEIS#'
               || '<p>Die Rechnung finden Sie als PDF im Anhang. Bei Fragen stehe ich Ihnen gerne zur Verfügung.</p>'
               || '<p>Mit freundlichen Grüßen</p>'
               || '<p>#ABSENDER#<br>' || p_firma || '<br>' || p_anschrift || '<br>' || p_kontakt || '</p>'
          from ADMIN_MANDANTEN m
         where m.MAND_CODE = p_code
           and not exists (select 1 from FAKT_MAIL_VORLAGEN v
                            where v.MVOR_MAND_ID = m.MAND_ID and v.MVOR_BELEGART = 'RECHNUNG');
        dbms_output.put_line('Vorlage ' || p_code || ': ' || sql%rowcount || ' angelegt');
    end vorlage;
begin
    vorlage('EDV', 'office@thg-edv.com', 'ThG - edv GmbH', 'Rosengasse 5, 8650 Kindberg',
            'office@thg-edv.com · +43 660 466 80 88');
    vorlage('HOLDING', 'office@gesslbauer.com', 'Thomas Geßlbauer GmbH', 'Maierleitn 1, 8661 St. Barbara',
            'office@gesslbauer.com · +43 660 466 80 88');
    commit;
end;
/

create or replace package FAKT_RECHNUNG_VERSAND as
    -- Vorschau (Dialog Seite 17): Absender = angemeldeter Mitarbeiter (MITA_EMAIL), Empfaenger aus dem Kunden bzw.
    -- Ansprechpartner der Rechnung, Bcc/Betreff/Text aus der Vorlage des Mandanten (Platzhalter ersetzt),
    -- Anhang = zuletzt abgelegter Rechnungsdruck (RDOK_ID; fehlt er, wird er erzeugt und abgelegt)
    procedure vorbelegen(p_rech_id in number,
                         o_von     out varchar2,
                         o_an      out varchar2,
                         o_bcc     out varchar2,
                         o_betreff out varchar2,
                         o_text    out clob,
                         o_rdok_id out number);
    -- E-Mail ueber Microsoft Graph senden (Absender = angemeldeter Mitarbeiter, Kopie in seinen Gesendeten Elementen),
    -- Anhang p_rdok_id; danach Status GEDRUCKT -> GESENDET und Historie "E-Mail versendet".
    -- Adressen: mehrere mit ; oder , getrennt
    procedure senden(p_rech_id in number,
                     p_an      in varchar2,
                     p_cc      in varchar2,
                     p_betreff in varchar2,
                     p_text    in clob,
                     p_rdok_id in number);
end FAKT_RECHNUNG_VERSAND;
/

create or replace package body FAKT_RECHNUNG_VERSAND as

    c_credential constant varchar2(30)  := 'entra-thgerp';
    c_token_url  constant varchar2(200) :=
        'https://login.microsoftonline.com/c93caac8-248c-440d-afb2-3777aed55fe9/oauth2/v2.0/token';
    c_graph      constant varchar2(100) := 'https://graph.microsoft.com/v1.0/users/';

    function rechnung(p_rech_id in number) return FAKT_RECHNUNGEN%rowtype is
        l_rech FAKT_RECHNUNGEN%rowtype;
    begin
        select * into l_rech from FAKT_RECHNUNGEN where RECH_ID = p_rech_id;
        if l_rech.RECH_STATUS not in ('GEDRUCKT', 'GESENDET', 'TEILBEZAHLT', 'BEZAHLT') then
            raise_application_error(-20261, 'Versenden nur für abgeschlossene Rechnungen'
                || case l_rech.RECH_STATUS when 'IN_BEARBEITUNG' then ' – bitte zuerst „Rechnung drucken“.'
                                           else '.' end);
        end if;
        return l_rech;
    end rechnung;

    -- Office-365-Adresse und Name des angemeldeten Mitarbeiters
    procedure absender(o_email out varchar2, o_name out varchar2) is
    begin
        select max(MITA_EMAIL), max(MITA_NAME) into o_email, o_name
          from ALLG_MITARBEITER
         where MITA_BENUTZERNAME = upper(coalesce(sys_context('APEX$SESSION', 'APP_USER'), user));
        if o_email is null then
            raise_application_error(-20262, 'Für Ihren Benutzer ist keine Office-365-Adresse eingetragen '
                                            || '(Einstellungen bzw. Mitarbeiter in THG-ADMIN).');
        end if;
    end absender;

    -- Adressliste vereinheitlichen ("a@x.at; b@y.at") und pruefen
    function adressen(p_liste in varchar2, p_feld in varchar2) return varchar2 is
        l_ergebnis varchar2(4000);
        l_adresse  varchar2(500);
    begin
        for i in 1 .. regexp_count(p_liste, '[^,;[:space:]]+') loop
            l_adresse := lower(regexp_substr(p_liste, '[^,;[:space:]]+', 1, i));
            if not regexp_like(l_adresse, '^[^@]+@[^@]+\.[a-z]{2,}$') then
                raise_application_error(-20263, p_feld || ': „' || l_adresse || '“ ist keine gültige E-Mail-Adresse.');
            end if;
            l_ergebnis := l_ergebnis || case when l_ergebnis is not null then '; ' end || l_adresse;
        end loop;
        return l_ergebnis;
    end adressen;

    function ersetzen(p_text in clob, p_rech in FAKT_RECHNUNGEN%rowtype, p_absender in varchar2) return clob is
        l_text   clob := p_text;
        l_anrede varchar2(500);
        l_offen  number;
        l_iban   varchar2(50);
        l_hinw   varchar2(2000);
    begin
        -- Anrede aus dem Ansprechpartner der Rechnung
        select max(case a.ANSP_ANREDE
                       when 'Herr' then 'Sehr geehrter Herr ' || trim(a.ANSP_TITEL || ' ' || a.ANSP_NACHNAME) || ','
                       when 'Frau' then 'Sehr geehrte Frau ' || trim(a.ANSP_TITEL || ' ' || a.ANSP_NACHNAME) || ','
                   end)
          into l_anrede
          from KUND_ANSPRECHPARTNER a
         where a.ANSP_ID = p_rech.RECH_ANSP_ID
           and a.ANSP_NACHNAME is not null;
        select max(OFFEN) into l_offen from FAKT_RECHNUNGEN_V where RECH_ID = p_rech.RECH_ID;
        select max(regexp_replace(MBNK_IBAN, '(.{4})', '\1 ')) keep (dense_rank first order by
                   case MBNK_IST_BEVORZUGT when 'Y' then 0 else 1 end, MBNK_SORTIERUNG)
          into l_iban
          from ADMIN_MANDANT_BANKVERBINDUNGEN
         where MBNK_MAND_ID = p_rech.RECH_MAND_ID and MBNK_IST_AKTIV = 'Y';
        -- Zahlungshinweis: offener Betrag, Faelligkeit, Konto, RF-Zahlungsreferenz (aeltere Rechnungen haben keine)
        l_hinw := case
                      when nvl(l_offen, 0) <= 0 then
                          '<p>Der Rechnungsbetrag ist bereits beglichen – vielen Dank.</p>'
                      else
                          '<p>Bitte überweisen Sie '
                          || case when l_offen < p_rech.RECH_SUMME_BRUTTO
                                  then 'den offenen Betrag von <strong>' || FAKT_HISTORIE.betrag(l_offen) || '</strong>'
                                  else 'den Betrag' end
                          || case when p_rech.RECH_FAELLIG_AM is not null
                                  then ' bis <strong>' || to_char(p_rech.RECH_FAELLIG_AM, 'DD.MM.YYYY') || '</strong>' end
                          || case when l_iban is not null then ' auf unser Konto ' || trim(l_iban) end
                          || case when p_rech.RECH_ZAHLUNGSREFERENZ is not null
                                  then ' und geben Sie dabei die Zahlungsreferenz <strong>'
                                       || FAKT_RECHNUNG.referenz_anzeige(p_rech.RECH_ZAHLUNGSREFERENZ) || '</strong> an' end
                          || '.</p>'
                  end;
        l_text := replace(l_text, '#ANREDE#', apex_escape.html(coalesce(l_anrede, 'Sehr geehrte Damen und Herren,')));
        l_text := replace(l_text, '#RECHNUNGSNUMMER#', apex_escape.html(p_rech.RECH_NUMMER));
        l_text := replace(l_text, '#RECHNUNGSDATUM#', to_char(p_rech.RECH_DATUM, 'DD.MM.YYYY'));
        l_text := replace(l_text, '#BETRAG#', FAKT_HISTORIE.betrag(p_rech.RECH_SUMME_BRUTTO));
        l_text := replace(l_text, '#FAELLIG_AM#', to_char(p_rech.RECH_FAELLIG_AM, 'DD.MM.YYYY'));
        l_text := replace(l_text, '#ZAHLUNGSHINWEIS#', l_hinw);
        l_text := replace(l_text, '#KUNDE#', apex_escape.html(p_rech.RECH_EMPF_NAME));
        l_text := replace(l_text, '#ABSENDER#', apex_escape.html(p_absender));
        return l_text;
    end ersetzen;

    -- zuletzt abgelegter Druck; fehlt er (z. B. uebernommene Rechnung), jetzt erzeugen und ablegen
    function anhang(p_rech_id in number) return number is
        l_rdok_id number;
    begin
        select max(RDOK_ID) keep (dense_rank last order by RDOK_VERSION) into l_rdok_id
          from FAKT_RECHNUNG_DOKUMENTE where RDOK_RECH_ID = p_rech_id;
        if l_rdok_id is null then
            FAKT_RECHNUNG_DOKUMENT.ablegen(p_rech_id, FAKT_RECHNUNG_PDF.pdf(p_rech_id));
            select max(RDOK_ID) keep (dense_rank last order by RDOK_VERSION) into l_rdok_id
              from FAKT_RECHNUNG_DOKUMENTE where RDOK_RECH_ID = p_rech_id;
        end if;
        return l_rdok_id;
    end anhang;

    procedure vorbelegen(p_rech_id in number,
                         o_von     out varchar2,
                         o_an      out varchar2,
                         o_bcc     out varchar2,
                         o_betreff out varchar2,
                         o_text    out clob,
                         o_rdok_id out number) is
        l_rech FAKT_RECHNUNGEN%rowtype := rechnung(p_rech_id);
        l_name ALLG_MITARBEITER.MITA_NAME%type;
    begin
        absender(o_von, l_name);
        -- Rechnungsadresse des Kunden, sonst die (bevorzugte) E-Mail des Ansprechpartners
        select coalesce(
                   (select k.KUND_EMAIL_RECHNUNG from KUND_KUNDEN k where k.KUND_ID = l_rech.RECH_KUND_ID),
                   (select max(c.AKOM_WERT) keep (dense_rank first order by case c.AKOM_IST_BEVORZUGT when 'Y' then 0 else 1 end)
                      from KUND_ANSPRECHPARTNER_KOMMUNIKATION c
                      join ALLG_KOMMUNIKATIONSARTEN t on t.KART_ID = c.AKOM_KART_ID and t.KART_CODE = 'EMAIL'
                     where c.AKOM_ANSP_ID = l_rech.RECH_ANSP_ID))
          into o_an
          from dual;
        begin
            select MVOR_BCC, MVOR_BETREFF, MVOR_TEXT into o_bcc, o_betreff, o_text
              from FAKT_MAIL_VORLAGEN
             where MVOR_MAND_ID = l_rech.RECH_MAND_ID and MVOR_BELEGART = 'RECHNUNG';
        exception
            when no_data_found then
                raise_application_error(-20264, 'Für den Mandanten der Rechnung ist keine E-Mail-Vorlage eingetragen.');
        end;
        o_betreff := replace(o_betreff, '#RECHNUNGSNUMMER#', l_rech.RECH_NUMMER);
        o_text    := ersetzen(o_text, l_rech, l_name);
        o_rdok_id := anhang(p_rech_id);
    end vorbelegen;

    procedure senden(p_rech_id in number,
                     p_an      in varchar2,
                     p_cc      in varchar2,
                     p_betreff in varchar2,
                     p_text    in clob,
                     p_rdok_id in number) is
        l_rech    FAKT_RECHNUNGEN%rowtype := rechnung(p_rech_id);
        l_von     ALLG_MITARBEITER.MITA_EMAIL%type;
        l_name    ALLG_MITARBEITER.MITA_NAME%type;
        l_an      varchar2(4000) := adressen(p_an, 'An');
        l_cc      varchar2(4000) := adressen(p_cc, 'Cc');
        l_bcc     FAKT_MAIL_VORLAGEN.MVOR_BCC%type;
        l_dok     FAKT_RECHNUNG_DOKUMENTE%rowtype;
        l_antwort clob;

        procedure empfaenger(p_name in varchar2, p_liste in varchar2) is
        begin
            if p_liste is null then
                return;
            end if;
            apex_json.open_array(p_name);
            for i in 1 .. regexp_count(p_liste, '[^; ]+') loop
                apex_json.open_object;
                apex_json.open_object('emailAddress');
                apex_json.write('address', regexp_substr(p_liste, '[^; ]+', 1, i));
                apex_json.close_object;
                apex_json.close_object;
            end loop;
            apex_json.close_array;
        end empfaenger;
    begin
        absender(l_von, l_name);
        if l_an is null then
            raise_application_error(-20265, 'Bitte mindestens einen Empfänger angeben.');
        end if;
        if trim(p_betreff) is null then
            raise_application_error(-20266, 'Bitte einen Betreff angeben.');
        end if;
        select max(MVOR_BCC) into l_bcc
          from FAKT_MAIL_VORLAGEN where MVOR_MAND_ID = l_rech.RECH_MAND_ID and MVOR_BELEGART = 'RECHNUNG';
        select * into l_dok from FAKT_RECHNUNG_DOKUMENTE where RDOK_ID = p_rdok_id and RDOK_RECH_ID = p_rech_id;

        apex_json.initialize_clob_output;
        apex_json.open_object;
        apex_json.open_object('message');
        apex_json.write('subject', p_betreff);
        apex_json.open_object('body');
        apex_json.write('contentType', 'HTML');
        apex_json.write('content', '<div style="font-family:Calibri,Arial,sans-serif;font-size:11pt">' || p_text || '</div>');
        apex_json.close_object;
        empfaenger('toRecipients', l_an);
        empfaenger('ccRecipients', l_cc);
        empfaenger('bccRecipients', l_bcc);
        apex_json.open_array('attachments');
        apex_json.open_object;
        apex_json.write('@odata.type', '#microsoft.graph.fileAttachment');
        apex_json.write('name', l_dok.RDOK_DATEINAME);
        apex_json.write('contentType', 'application/pdf');
        apex_json.write('contentBytes', apex_web_service.blob2clobbase64(l_dok.RDOK_DATEI, p_newlines => 'N', p_padding => 'Y'));
        apex_json.close_object;
        apex_json.close_array;
        apex_json.close_object;
        apex_json.write('saveToSentItems', true);
        apex_json.close_object;

        apex_web_service.set_request_headers(p_name_01 => 'Content-Type', p_value_01 => 'application/json');
        l_antwort := apex_web_service.make_rest_request(
            p_url                  => c_graph || apex_util.url_encode(l_von) || '/sendMail',
            p_http_method          => 'POST',
            p_body                 => apex_json.get_clob_output,
            p_credential_static_id => c_credential,
            p_token_url            => c_token_url);
        apex_json.free_output;
        if apex_web_service.g_status_code <> 202 then
            raise_application_error(-20267, 'E-Mail wurde nicht versendet (Microsoft Graph, HTTP '
                || apex_web_service.g_status_code || '): '
                || coalesce(json_value(l_antwort, '$.error.message'), dbms_lob.substr(l_antwort, 500, 1)));
        end if;

        -- Status: GEDRUCKT -> GESENDET (Historie "Gesendet" per Trigger); bezahlte bzw. teilbezahlte bleiben
        update FAKT_RECHNUNGEN set RECH_STATUS = 'GESENDET' where RECH_ID = p_rech_id and RECH_STATUS = 'GEDRUCKT';
        FAKT_HISTORIE.protokoll(p_rech_id, 'E-Mail versendet',
            'Von: ' || l_von || '; An: ' || l_an || nvl2(l_cc, '; Cc: ' || l_cc, null) || nvl2(l_bcc, '; Bcc: ' || l_bcc, null)
            || '; Betreff: ' || p_betreff || '; Anhang: ' || l_dok.RDOK_DATEINAME);
    exception
        when others then
            apex_json.free_output;
            raise;
    end senden;

end FAKT_RECHNUNG_VERSAND;
/

show errors package body FAKT_RECHNUNG_VERSAND

prompt Rechnungsversand installiert.
