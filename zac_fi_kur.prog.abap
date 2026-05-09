*&---------------------------------------------------------------------*
*& Report  ZAC_FI_KUR
*&
*&---------------------------------------------------------------------*
*&
*&
*&---------------------------------------------------------------------*

report  zac_fi_kur.

type-pools: slis.

data: gt_fieldcat type slis_t_fieldcat_alv with header line,
      gs_fieldcat type slis_fieldcat_alv,
      gs_layout type slis_layout_alv,
      rs_selfield type slis_selfield.

tables : zfi_tkur, "Döviz kurları convertion table
         tcurr  , "Çeviri kurları
         tcurf  . "Dönüştürme faktörleri

*&---------------------------------------------------------------------*
*   Internal tables
*&---------------------------------------------------------------------*

data : begin of rtab occurs 0,
       line(255)  ,
       end   of rtab .

data : begin of itab occurs 0 ,
       fcurr like tcurr-fcurr ,
       tcurr like tcurr-fcurr ,
       text(30) ,
*      value1(9) type p decimals 2 ,
       value1(12) type n ,
       value2(12) type n ,
       value3(12) type n ,
       value4(12) type n ,
       end   of itab .

data : begin of i_tcurr occurs 0 .
        include structure tcurr .
data : sapma(8) type p decimals 2 ,
       end   of i_tcurr .

data tcurr_gdatu like tcurr-gdatu.

data: begin of response_headers occurs 0,
      line(255) type c,
      end of response_headers.

data : ukurs type p decimals 5.
data : hata.
data : head .
data : datum like sy-datum.


define corr_text.
  translate &1 using ', '.
  condense &1 no-gaps.
end-of-definition.

*&---------------------------------------------------------------------*

parameters : pdate like sy-datum obligatory default sy-datum,
             pgun  type n default '1' obligatory .

*PARAMETERS : r1 RADIOBUTTON GROUP rad DEFAULT 'X' ,
*             r2 RADIOBUTTON GROUP rad  .
*&---------------------------------------------------------------------*

at selection-screen.
  if pdate le '20020128'.
    message id '00' type 'W' number '398' with
      '28.01.2002 Tarihi öncesi için kur dosyası formatı farklı' .
  endif.

  datum = sy-datum + 1.

  if pdate gt datum.
    message id '00' type 'W' number '398' with
        'İleriye dönük tarihli kur girişi yapılamaz' .
  endif.
*&---------------------------------------------------------------------*

start-of-selection.
*  IF r1 EQ 'X' .
  perform http_get_file.
*  ELSE.
*    PERFORM read_text .
*  ENDIF.
  perform fill_itab .
  perform modify_itab.
  perform fill_i_tcurr.
*  PERFORM cross_rates.
  perform sapma.
  perform ek_gec_gun.

  sort i_tcurr by gdatu descending kurst fcurr tcurr.

*&---------------------------------------------------------------------*

top-of-page .
  perform top_of_page.
*&---------------------------------------------------------------------*

end-of-selection  .
  set pf-status 'MENU' .
  perform write_data .

at user-command.
  perform user_command.

*&---------------------------------------------------------------------*
*&      Form  read_text
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
form read_text.
  call function 'UPLOAD'
    tables
      data_tab                = rtab
    exceptions
      conversion_error        = 1
      invalid_table_width     = 2
      invalid_type            = 3
      no_batch                = 4
      unknown_error           = 5
      gui_refuse_filetransfer = 6
      others                  = 7.

  if sy-subrc <> 0.
    message id sy-msgid type sy-msgty number sy-msgno
            with sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
    exit.
  endif.


endform.                    " read_text


*&---------------------------------------------------------------------*
*&      Form  dump_data
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
form dump_data.
  refresh gt_fieldcat.
  clear gt_fieldcat.
  clear gs_fieldcat.
  perform build_catalog.

  call function 'REUSE_ALV_GRID_DISPLAY'
    exporting
      i_callback_program       = 'ZFI_KUR'
*      IS_LAYOUT                = GS_LAYOUT
*      I_CALLBACK_USER_COMMAND  = 'USER_COMMAND'
*      i_callback_pf_status_set = 'SET_GUI'
*      I_CALLBACK_PF_STATUS_SET = 'SET_PF_STATUS'
      it_fieldcat              = gt_fieldcat[]
    tables
      t_outtab                 = i_tcurr
    exceptions
      program_error            = 1
      others                   = 2.
endform.                    " dump_data

*&---------------------------------------------------------------------*
*&      Form  set_gui
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->RT_EXTAB   text
*----------------------------------------------------------------------*
form set_gui using rt_extab type slis_t_extab.
  set pf-status 'ZMENU'.
endform.                    "set_gui

*&---------------------------------------------------------------------*
*&      Form  update_tcurc
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
form update_tcurc.
  data : answer, tline1(50) , tline2(50).
  tline1 = 'Bu Kurlar tüm moduller tarafından kullanılacak.'.
  tline2 = 'Kaydedildikten sonra değiştirilmesi sakıncalıdır'.

  if hata eq 'X' .
    message id '00' type 'I' number '368' with
           'Hatalar düzeltilmeden veriler kaydedilemez!!!' .
  endif.
  check hata eq space.

  call function 'POPUP_TO_CONFIRM_STEP'
    exporting
      defaultoption = 'Y'
      textline1     = tline1
      textline2     = tline2
      titel         = 'DİKKAT'
    importing
      answer        = answer.
  check answer eq 'Y'
     or answer eq 'J' .
  if pgun gt 1 .
    clear: tline1 , tline2 .
    write pdate to tline1.
    concatenate 'Girilen kurlar' tline1 'tarihinden itibaren'
                into tline1 separated by space.
    concatenate pgun 'Gün boyunca geçerli olacaktır!!!'
                into tline2 separated by space.

    call function 'POPUP_TO_CONFIRM_STEP'
      exporting
        defaultoption = 'N'
        textline1     = tline1
        textline2     = tline2
        titel         = 'DİKKAT'
      importing
        answer        = answer.
    check answer eq 'Y'
       or answer eq 'J' .
  endif.

  loop at i_tcurr.
    clear tcurr .
    move-corresponding i_tcurr to tcurr.
    modify tcurr.
  endloop.

  if sy-subrc eq 0.
    message id '00' type 'S' number '368' with
               'Veriler Kaydedildi....' .
  endif.

endform.                    " update_tcurr


*&---------------------------------------------------------------------*
*&      Form  fill_itab
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
form fill_itab.
  data : c1(15) ,
         c2(15) ,
         c3(15) ,
         c4(15) ,
         c5(15) .

  refresh itab .

  loop at rtab .
    if rtab-line cs 'ÇAPRAZ KURLAR' .
      exit.
    else.
      delete rtab.
    endif.

    clear itab .
    itab-fcurr = rtab-line(3) .
    itab-text  = rtab-line+4(29).

    do 100 times.
      shift rtab-line+33(80) left  deleting leading space.
      replace '  ' with ' ' into rtab-line+33(80).
      if sy-subrc ne 0.
        exit.
      endif.
    enddo.

    split rtab-line+33(70) at ' ' into c1 c2 c3 c4 c5.
    corr_text : c1 ,
                c2 ,
                c3 ,
                c4 ,
                c5 .
    itab-value1 = c1 .
    itab-value2 = c2 .
    itab-value3 = c3 .
    itab-value4 = c4 .
    ....
    append itab.
  endloop.
endform.                    " fill_itab

*&---------------------------------------------------------------------*
*&      Form  modify_itab
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
form modify_itab.
  data: buf_val1(12) type n,
        buf_val2(12) type n.
  clear: buf_val1,
         buf_val2.
****** Added by Alper Karabulut.
  "USDS için eklenen kod
  read table itab with key fcurr = 'USD'.
  if sy-subrc eq 0.
    buf_val1 = itab-value1.
    buf_val2 = itab-value2.
    itab-value1 = buf_val2.
    itab-value2 = buf_val2."Alış ve Satış kuru satış kuru oldu.
    itab-fcurr = 'USDS'.
    append itab.
  endif.
  clear: buf_val1,
         buf_val2.
  "EURS için eklenen kod
  read table itab with key fcurr = 'EUR'.
  if sy-subrc eq 0.
    buf_val1 = itab-value1.
    buf_val2 = itab-value2.
    itab-value1 = buf_val2.
    itab-value2 = buf_val2.
    itab-fcurr = 'EURS'.
    append itab.
  endif.
******
  loop at itab .
    clear zfi_tkur.
    select single * from zfi_tkur where fcurr eq itab-fcurr.
    if sy-subrc ne 0 .
      delete itab .
      check 1 = 2 .
    endif.
    itab-tcurr = zfi_tkur-tcurr.
    if itab-tcurr ne 'USD' and
       itab-tcurr ne 'EUR' and
       itab-tcurr ne 'CHF' and
       itab-tcurr ne 'GBP' and
       itab-tcurr ne 'TRY' and
       itab-tcurr ne 'JPY' and
       itab-tcurr ne 'SEK' and
       itab-tcurr ne 'USDS' and
       itab-tcurr ne 'EURS'  .
      delete itab.
    else.
      modify itab.
    endif.
  endloop.
endform.                    " modify_itab



*&---------------------------------------------------------------------*
*&      Form  fill_i_tcurr
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
form fill_i_tcurr.

  data : value(8).
  refresh i_tcurr.

  convert date pdate into inverted-date tcurr_gdatu.

  loop at itab .
*   M Tipi kurların girişi
    if not itab-value1 is initial .
      clear i_tcurr.
      i_tcurr-kurst = 'M' .
      i_tcurr-fcurr = itab-tcurr.
      i_tcurr-tcurr = 'TRY'.
      i_tcurr-gdatu = tcurr_gdatu .
*   kur dönüşümü için faktörler

      select * from tcurf
           where  kurst       =  i_tcurr-kurst
           and    fcurr       =  i_tcurr-fcurr
           and    tcurr       =  i_tcurr-tcurr
           and    gdatu       ge tcurr_gdatu
           order by primary key.
      endselect.

      if sy-subrc ne 0 .
        format color col_negative . hata = 'X' .
        write : / itab-tcurr , itab-text ,i_tcurr-kurst,
                 'Kur tipi için çeviri faktörü bulunamadı' .
      else.
*     kayıt kontrolu

        select single * from tcurr
           where  kurst       =  i_tcurr-kurst
           and    fcurr       =  i_tcurr-fcurr
           and    tcurr       =  i_tcurr-tcurr
           and    gdatu       =  tcurr_gdatu.

        if sy-subrc eq 0.
          format color col_negative . hata = 'X' .
          write : / itab-tcurr , itab-text ,i_tcurr-kurst,
                 'kuru sistemde mevcut' .
        else.
          value = itab-value1+7(5).
          value = value / 10000.
****** changed by sina on 25.12.2007
          if itab-fcurr eq 'JPY' .
            value = value / 100.
          endif.
          if itab-fcurr eq 'CHF' and value gt 2.
            value = value / 10.
          endif.
*        replace '.' with ',' into value.
*         ukurs = itab-value1 * tcurf-ffact / tcurf-tfact.
          ukurs = value * tcurf-ffact / tcurf-tfact.
          if i_tcurr-fcurr eq 'ITL'.
            ukurs = ukurs / 100.
          endif.
          i_tcurr-ukurs = ukurs.
          i_tcurr-ffact = tcurf-ffact.
          i_tcurr-tfact = tcurf-tfact.
          append i_tcurr.

*          if ukurs le '9999' .
*            i_tcurr-ukurs = ukurs.
*            i_tcurr-ffact = tcurf-ffact.
*            i_tcurr-tfact = tcurf-tfact.
*            append i_tcurr.
*          else.
*            write : / tcurf-kurst , tcurf-fcurr ,
*                     'kur tipi için çeviri faktörü düzeltilmeli'.
*          endif.
        endif.
      endif.
    endif.

*   S Tipi kurların girişi
    if not itab-value2 is initial .
      clear i_tcurr.
      i_tcurr-kurst = 'S' .
      i_tcurr-fcurr = itab-tcurr.
      i_tcurr-tcurr = 'TRY'.
      i_tcurr-gdatu = tcurr_gdatu .

*   kur dönüşümü için faktörler

      select * from tcurf
           where  kurst       =  i_tcurr-kurst
           and    fcurr       =  i_tcurr-fcurr
           and    tcurr       =  i_tcurr-tcurr
           and    gdatu       ge tcurr_gdatu
           order by primary key.
      endselect.

      if sy-subrc ne 0 .
        format color col_negative . hata = 'X' .
        write : / itab-tcurr , itab-text , i_tcurr-kurst ,
                  'Kur tipi için çeviri faktörü bulunamadı' .
      else.
*     kayıt kontrolu
        select single * from tcurr
           where  kurst       =  i_tcurr-kurst
           and    fcurr       =  i_tcurr-fcurr
           and    tcurr       =  i_tcurr-tcurr
           and    gdatu       =  tcurr_gdatu.
        if sy-subrc eq 0.
          format color col_negative . hata = 'X' .
          write : / itab-tcurr , itab-text ,i_tcurr-kurst,
                 'kuru sistemde mevcut' .
        else.
          clear value.
          value = itab-value2+7(5).
          value = value / 10000.
******* changed by sina on 25.12.2007
          if itab-fcurr eq 'JPY' .
            value = value / 100.
          endif.
*************
*        replace '.' with ',' into value.
*          ukurs = itab-value2 * tcurf-ffact / tcurf-tfact.
          ukurs = value * tcurf-ffact / tcurf-tfact.
          if i_tcurr-fcurr eq 'ITL'.
            ukurs = ukurs / 100.
          endif.
          i_tcurr-ukurs = ukurs.
          i_tcurr-ffact = tcurf-ffact.
          i_tcurr-tfact = tcurf-tfact.
          append i_tcurr.
*          if ukurs le '9999' .
*            i_tcurr-ukurs = ukurs.
*            i_tcurr-ffact = tcurf-ffact.
*            i_tcurr-tfact = tcurf-tfact.
*            append i_tcurr.
*          else.
*            write : / tcurf-kurst , tcurf-fcurr ,
*                     'kur tipi için çeviri faktörü düzeltilmeli'.
*          endif.
        endif.
      endif.
    endif.

*   E Tipi kurların girişi
    if not itab-value3 is initial .
      clear i_tcurr.
      i_tcurr-kurst = 'E' .
      i_tcurr-fcurr = itab-tcurr.
      i_tcurr-tcurr = 'TRY'.
      i_tcurr-gdatu = tcurr_gdatu .
*   kur dönüşümü için faktörler

      select * from tcurf
           where  kurst       =  i_tcurr-kurst
           and    fcurr       =  i_tcurr-fcurr
           and    tcurr       =  i_tcurr-tcurr
           and    gdatu       ge tcurr_gdatu
           order by primary key.
      endselect.

      if sy-subrc ne 0 .
        format color col_negative . hata = 'X' .
        write : / itab-tcurr , itab-text ,i_tcurr-kurst,
                 'Kur tipi için çeviri faktörü bulunamadı' .
      else.
*     kayıt kontrolu

        select single * from tcurr
           where  kurst       =  i_tcurr-kurst
           and    fcurr       =  i_tcurr-fcurr
           and    tcurr       =  i_tcurr-tcurr
           and    gdatu       =  tcurr_gdatu.

        if sy-subrc eq 0.
          format color col_negative . hata = 'X' .
          write : / itab-tcurr , itab-text ,i_tcurr-kurst,
                 'kuru sistemde mevcut' .
        else.
          value = itab-value3+7(5).
          value = value / 10000.
****** changed by sina on 25.12.2007
          if itab-fcurr eq 'JPY' .
            value = value / 100.
          endif.
          if itab-fcurr eq 'CHF' and value gt 2.
            value = value / 10.
          endif.
*        replace '.' with ',' into value.
*         ukurs = itab-value1 * tcurf-ffact / tcurf-tfact.
          ukurs = value * tcurf-ffact / tcurf-tfact.
          if i_tcurr-fcurr eq 'ITL'.
            ukurs = ukurs / 100.
          endif.
          i_tcurr-ukurs = ukurs.
          i_tcurr-ffact = tcurf-ffact.
          i_tcurr-tfact = tcurf-tfact.
          append i_tcurr.

*          if ukurs le '9999' .
*            i_tcurr-ukurs = ukurs.
*            i_tcurr-ffact = tcurf-ffact.
*            i_tcurr-tfact = tcurf-tfact.
*            append i_tcurr.
*          else.
*            write : / tcurf-kurst , tcurf-fcurr ,
*                     'kur tipi için çeviri faktörü düzeltilmeli'.
*          endif.
        endif.
      endif.
    endif.

*   F Tipi kurların girişi
    if not itab-value4 is initial .
      clear i_tcurr.
      i_tcurr-kurst = 'F' .
      i_tcurr-fcurr = itab-tcurr.
      i_tcurr-tcurr = 'TRY'.
      i_tcurr-gdatu = tcurr_gdatu .
*   kur dönüşümü için faktörler

      select * from tcurf
           where  kurst       =  i_tcurr-kurst
           and    fcurr       =  i_tcurr-fcurr
           and    tcurr       =  i_tcurr-tcurr
           and    gdatu       ge tcurr_gdatu
           order by primary key.
      endselect.

      if sy-subrc ne 0 .
        format color col_negative . hata = 'X' .
        write : / itab-tcurr , itab-text ,i_tcurr-kurst,
                 'Kur tipi için çeviri faktörü bulunamadı' .
      else.
*     kayıt kontrolu

        select single * from tcurr
           where  kurst       =  i_tcurr-kurst
           and    fcurr       =  i_tcurr-fcurr
           and    tcurr       =  i_tcurr-tcurr
           and    gdatu       =  tcurr_gdatu.

        if sy-subrc eq 0.
          format color col_negative . hata = 'X' .
          write : / itab-tcurr , itab-text ,i_tcurr-kurst,
                 'kuru sistemde mevcut' .
        else.
          value = itab-value4+7(5).
          value = value / 10000.
****** changed by sina on 25.12.2007
          if itab-fcurr eq 'JPY' .
            value = value / 100.
          endif.
          if itab-fcurr eq 'CHF' and value gt 2.
            value = value / 10.
          endif.
*        replace '.' with ',' into value.
*         ukurs = itab-value1 * tcurf-ffact / tcurf-tfact.
          ukurs = value * tcurf-ffact / tcurf-tfact.
          if i_tcurr-fcurr eq 'ITL'.
            ukurs = ukurs / 100.
          endif.
          i_tcurr-ukurs = ukurs.
          i_tcurr-ffact = tcurf-ffact.
          i_tcurr-tfact = tcurf-tfact.
          append i_tcurr.

*          if ukurs le '9999' .
*            i_tcurr-ukurs = ukurs.
*            i_tcurr-ffact = tcurf-ffact.
*            i_tcurr-tfact = tcurf-tfact.
*            append i_tcurr.
*          else.
*            write : / tcurf-kurst , tcurf-fcurr ,
*                     'kur tipi için çeviri faktörü düzeltilmeli'.
*          endif.
        endif.
      endif.
    endif.


  endloop.





endform.                    " fill_i_tcurr

*&---------------------------------------------------------------------*

*&      Form  top_of_page

*&---------------------------------------------------------------------*

*       text

*----------------------------------------------------------------------*

*  -->  p1        text

*  <--  p2        text

*----------------------------------------------------------------------*

form top_of_page.

  if head eq 'X' .

    format color col_heading.

    write :

         /(10)   'Kur Tipi' ,

          (10)   'Kaynak PB',

          (10)   'Hedef PB' ,

          (10)   'Tarih' ,

          (20)   'Çeviri kuru',

          (10)   'Oran-Kyn',

          (10)   'Oran-Hed',

          (10)   'Sapma'   .

  else.

    format color col_heading.

    write : / 'HATA LİSTESİ' .

  endif.

  uline.



endform.                    " top_of_page

*&---------------------------------------------------------------------*

*&      Form  HTTP_GET_FILE

*&---------------------------------------------------------------------*

*       text

*----------------------------------------------------------------------*

form http_get_file.



  data: uri(4096) type c value

                  'http://www.tcmb.gov.tr/kurlar/today.html' ,

        dest like rfcdes-rfcdest value 'SAPHTTP',

        user(40) type c ,

        password(40) type c ,

        path(80) type c .



  data: status(3) type c,

        key type i value 1303621,

        dstlen type i.

  data : pdate_ like pdate.



  data : filename like  rlgrap-filename.



  if pdate le sy-datum .

    pdate_ = pdate - 1.

    concatenate 'http://www.tcmb.gov.tr/kurlar/'

                pdate_(6) '/'

                pdate_+6(2)

                pdate_+4(2)

                pdate_(4)

                '.html'

                into uri.

  endif.





  concatenate 'C:\kur\' pdate '.TXT' into path.





  filename = path.



  describe field user length dstlen in character mode.

  call 'AB_RFC_X_SCRAMBLE_STRING'

    id 'SOURCE'      field user        id 'KEY'         field key

    id 'SCR'         field 'X'         id 'DESTINATION' field user

    id 'DSTLEN'      field dstlen.

  describe field password length dstlen in character mode.

  call 'AB_RFC_X_SCRAMBLE_STRING'

    id 'SOURCE'      field password    id 'KEY'         field key

    id 'SCR'         field 'X'         id 'DESTINATION' field password

    id 'DSTLEN'      field dstlen.



  call function 'HTTP_GET_FILE'

* path siz      'HTTP_GET'

       exporting

            absolute_uri     = uri

            rfc_destination  = dest

            user             = user

            password         = password

            document_path    = path

       importing

            status_code      = status

       tables

            response_headers = response_headers.



  call function 'WS_UPLOAD'
    exporting
      filename                = filename
      filetype                = 'DAT'
    tables
      data_tab                = rtab
    exceptions
      conversion_error        = 1
      invalid_table_width     = 2
      invalid_type            = 3
      no_batch                = 4
      unknown_error           = 5
      gui_refuse_filetransfer = 6
      others                  = 7.



  if sy-subrc <> 0.

    message id sy-msgid type sy-msgty number sy-msgno

            with sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.

    hata = 'X' .

  endif.





endform.                    " HTTP_GET_FILE

*&---------------------------------------------------------------------*

*&      Form  Cross_Rates

*&---------------------------------------------------------------------*

*       text

*----------------------------------------------------------------------*

*  -->  p1        text

*  <--  p2        text

*----------------------------------------------------------------------*

form cross_rates.

  data : value like i_tcurr-ukurs.





* USD çapraz kurlar

  loop at rtab .

    clear i_tcurr.

    if rtab-line cs 'CHF/USD' .

      i_tcurr-tcurr = 'CHF'.

      i_tcurr-fcurr = 'USD'.

    elseif rtab-line cs 'SEK/USD' .

      i_tcurr-tcurr = 'SEK'.

      i_tcurr-fcurr = 'USD'.

    elseif rtab-line cs 'JPY/USD' .

      i_tcurr-tcurr = 'JPY'.

      i_tcurr-fcurr = 'USD'.

    elseif rtab-line cs 'USD/EUR' .

      i_tcurr-tcurr = 'USD'.

      i_tcurr-fcurr = 'EUR'.

    elseif rtab-line cs 'USD/GBP' .

      i_tcurr-tcurr = 'USD'.

      i_tcurr-fcurr = 'GBP'.

    endif.

    check i_tcurr-fcurr ne space.

    i_tcurr-kurst = 'M' .

    i_tcurr-gdatu = tcurr_gdatu .

    value = rtab-line+38(10).



*   kur dönüşümü için faktörler

    select * from tcurf

         where  kurst       =  i_tcurr-kurst

         and    fcurr       =  i_tcurr-fcurr

         and    tcurr       =  i_tcurr-tcurr

         and    gdatu       ge tcurr_gdatu

         order by primary key.

    endselect.

    if sy-subrc ne 0 .

      format color col_negative . hata = 'X' .

      write : / i_tcurr-tcurr , i_tcurr-kurst,

                'Kur tipi için çeviri faktörü bulunamadı' .

    else.

*     kayıt kontrolu

      select single * from tcurr

         where  kurst       =  i_tcurr-kurst

         and    fcurr       =  i_tcurr-fcurr

         and    tcurr       =  i_tcurr-tcurr

         and    gdatu       =  tcurr_gdatu.

      if sy-subrc eq 0.

        format color col_negative . hata = 'X' .

        write : / i_tcurr-fcurr , i_tcurr-tcurr , i_tcurr-kurst,

               'kuru sistemde mevcut' .

      else.

        ukurs = value * tcurf-ffact / tcurf-tfact.

        if i_tcurr-fcurr eq 'ITL'.

          ukurs = ukurs / 100.

        endif.

*        if ukurs le '9999' .

*          i_tcurr-ukurs = ukurs.

*          i_tcurr-ffact = tcurf-ffact.

*          i_tcurr-tfact = tcurf-tfact.

*          append i_tcurr.

*          i_tcurr-kurst = 'S' .

*          append i_tcurr.

*        else.

*          write : / tcurf-kurst , tcurf-fcurr ,

*                   'kur tipi için çeviri faktörü düzeltilmeli'.

*        endif.

      endif.

    endif.



  endloop.

  check sy-subrc eq 0.



* EUR çapraz kurları

  perform eur_capraz using 'TRY' 'GBP' 'M'.

  perform eur_capraz using 'TRY' 'CHF' 'M'.

  perform eur_capraz using 'TRY' 'USD' 'M'.

  perform eur_capraz using 'TRY' 'EUR' 'M'.

  perform eur_capraz using 'TRY' 'GBP' 'S'.

  perform eur_capraz using 'TRY' 'CHF' 'S'.

  perform eur_capraz using 'TRY' 'USD' 'S'.

  perform eur_capraz using 'TRY' 'EUR' 'S'.



*  perform eur_capraz using 'GBP' 'EUR' 'M'.

*  perform eur_capraz using 'JPY' 'EUR' 'M'.

*  perform eur_capraz using 'SEK' 'EUR' 'M'.

*  perform eur_capraz using 'CHF' 'EUR' 'M'.

*  perform eur_capraz using 'GBP' 'EUR' 'S'.

*  perform eur_capraz using 'JPY' 'EUR' 'S'.

*  perform eur_capraz using 'SEK' 'EUR' 'S'.

*  perform eur_capraz using 'CHF' 'EUR' 'S'.



endform.                    " Cross_Rates

*&---------------------------------------------------------------------*

*&      Form  eur_capraz

*&---------------------------------------------------------------------*

*       text

*----------------------------------------------------------------------*

*  -->  p1        text

*  <--  p2        text

*----------------------------------------------------------------------*

form eur_capraz using tcurr fcurr kurst.

  data : t_tcurr like i_tcurr.



  clear i_tcurr .

  i_tcurr-tcurr = tcurr.

  i_tcurr-fcurr = fcurr.

  i_tcurr-kurst = kurst.

  i_tcurr-gdatu = tcurr_gdatu.

  select * from tcurf

       where  kurst       =  i_tcurr-kurst

       and    fcurr       =  i_tcurr-fcurr

       and    tcurr       =  i_tcurr-tcurr

       and    gdatu       ge tcurr_gdatu

       order by primary key.

  endselect.

  if sy-subrc ne 0 .

    format color col_negative . hata = 'X' .

    write : / i_tcurr-fcurr ,i_tcurr-tcurr,i_tcurr-kurst,

              'Kur tipi için çeviri faktörü bulunamadı' .

  else.

    read table i_tcurr into t_tcurr with key fcurr = i_tcurr-fcurr

                                             tcurr = 'TRY'

                                             kurst = kurst.

    ukurs = t_tcurr-ukurs.

    read table i_tcurr into t_tcurr with key fcurr = i_tcurr-tcurr

                                             tcurr = 'TRY'

                                             kurst = kurst.

    ukurs = ukurs / t_tcurr-ukurs .



    i_tcurr-ukurs = ukurs * tcurf-ffact / tcurf-tfact.

    i_tcurr-ffact = tcurf-ffact.

    i_tcurr-tfact = tcurf-tfact.

    append i_tcurr.

  endif.





endform.                    " eur_capraz

*&---------------------------------------------------------------------*

*&      Form  user_command

*&---------------------------------------------------------------------*

*       text

*----------------------------------------------------------------------*

*  -->  p1        text

*  <--  p2        text

*----------------------------------------------------------------------*



form user_command. " using r_ucomm     like sy-ucomm

  " rs_selfield type slis_selfield.

  case sy-ucomm.

    when 'BACK' or 'EXIT'.
      leave to screen 0.

    when 'CANC'.
      leave program.

    when 'ALV' .

      perform dump_data .

    when 'SAVE' .

      perform update_tcurc.

  endcase.



endform.                    " user_command





*&---------------------------------------------------------------------*

*&      Form  write_data

*&---------------------------------------------------------------------*

*       text

*----------------------------------------------------------------------*

*  -->  p1        text

*  <--  p2        text

*----------------------------------------------------------------------*

form write_data.

  data : spm like i_tcurr-sapma.

  head = 'X' .



  new-page.

  loop at i_tcurr .

    format color col_normal.

    spm = i_tcurr-sapma.

    if spm lt 0.

      spm = - spm.

    endif.



    write :

         /(10)   i_tcurr-kurst,

          (10)   i_tcurr-fcurr,

          (10)   i_tcurr-tcurr,

          (10)   i_tcurr-gdatu.



    if i_tcurr-ukurs gt 0 and spm le 10 .

      write: (20) i_tcurr-ukurs right-justified  .

    elseif i_tcurr-ukurs gt 0 and

           ( spm gt  10 and spm le  100 ).

      write: (20) i_tcurr-ukurs right-justified color col_total.

    elseif i_tcurr-ukurs gt 0 and

             spm gt  100 .

      write: (20) i_tcurr-ukurs right-justified color col_negative.

    elseif i_tcurr-ukurs le 0.

      hata = 'X' .

      write: (20) i_tcurr-ukurs right-justified color col_negative.

    endif.

    write:

         (10)   i_tcurr-ffact,

         (10)   i_tcurr-tfact,

         (10)   i_tcurr-sapma.

  endloop.



  uline.

endform.                    " write_data

*&---------------------------------------------------------------------*

*&      Form  sapma

*&---------------------------------------------------------------------*

*       text

*----------------------------------------------------------------------*

*  -->  p1        text

*  <--  p2        text

*----------------------------------------------------------------------*

form sapma.



  loop at i_tcurr .

    clear tcurr.

    select single * from tcurr where kurst eq i_tcurr-kurst

                                 and fcurr eq i_tcurr-fcurr

                                 and tcurr eq i_tcurr-tcurr

                                 and gdatu ge i_tcurr-gdatu.

    check sy-subrc eq 0

      and i_tcurr-ukurs ne 0.

    i_tcurr-sapma =  i_tcurr-ukurs - tcurr-ukurs  .

    i_tcurr-sapma =  i_tcurr-sapma * 100 / tcurr-ukurs.

    modify i_tcurr.



  endloop.



endform.                    " sapma

*&---------------------------------------------------------------------*

*&      Form  ek_gec_gun

*&---------------------------------------------------------------------*

*       text

*----------------------------------------------------------------------*

*  -->  p1        text

*  <--  p2        text

*----------------------------------------------------------------------*

form ek_gec_gun.

  data: edate like sy-datum.



  check pgun gt 1 .

  pgun = pgun - 1 .

  do pgun times.

    loop at i_tcurr where gdatu eq tcurr_gdatu.

      convert inverted-date i_tcurr-gdatu into date edate.

      edate = edate + sy-index .

      convert date edate into inverted-date i_tcurr-gdatu.

      append i_tcurr.

    endloop.

  enddo.



endform.                    " ek_gec_gun

*&---------------------------------------------------------------------*

*&      Form  build_catalog

*&---------------------------------------------------------------------*



form build_catalog .



  clear gs_fieldcat.

  gs_fieldcat-fieldname = 'KURST'.

  gs_fieldcat-ref_tabname = 'TCURR'.

  gs_fieldcat-ref_fieldname = 'KURST'.

*  gs_fieldcat-outputlen = '11'.

  append gs_fieldcat to gt_fieldcat.



  clear gs_fieldcat.

  gs_fieldcat-fieldname = 'FCURR'.

  gs_fieldcat-ref_tabname = 'TCURR'.

  gs_fieldcat-ref_fieldname = 'FCURR'.

*  gs_fieldcat-outputlen = '11'.

  append gs_fieldcat to gt_fieldcat.



  clear gs_fieldcat.

  gs_fieldcat-fieldname = 'TCURR'.

  gs_fieldcat-ref_tabname = 'TCURR'.

  gs_fieldcat-ref_fieldname = 'TCURR'.

*  gs_fieldcat-outputlen = '11'.

  append gs_fieldcat to gt_fieldcat.



  clear gs_fieldcat.

  gs_fieldcat-fieldname = 'GDATU'.

  gs_fieldcat-ref_tabname = 'TCURR'.

  gs_fieldcat-ref_fieldname = 'GDATU'.

*  gs_fieldcat-outputlen = '11'.

  append gs_fieldcat to gt_fieldcat.



  clear gs_fieldcat.

  gs_fieldcat-fieldname = 'UKURS'.

  gs_fieldcat-ref_tabname = 'TCURR'.

  gs_fieldcat-ref_fieldname = 'UKURS'.

*  gs_fieldcat-outputlen = '11'.

  append gs_fieldcat to gt_fieldcat.



  clear gs_fieldcat.

  gs_fieldcat-fieldname = 'FFACT'.

  gs_fieldcat-ref_tabname = 'TCURR'.

  gs_fieldcat-ref_fieldname = 'FFACT'.

*  gs_fieldcat-outputlen = '11'.

  append gs_fieldcat to gt_fieldcat.





  clear gs_fieldcat.

  gs_fieldcat-fieldname = 'TFACT'.

  gs_fieldcat-ref_tabname = 'TCURR'.

  gs_fieldcat-ref_fieldname = 'TFACT'.

*  gs_fieldcat-outputlen = '11'.

  append gs_fieldcat to gt_fieldcat.



  clear gs_fieldcat.

  gs_fieldcat-fieldname = 'TFACT'.

  gs_fieldcat-reptext_ddic = 'Sapma'.

*  gs_fieldcat-ref_fieldname = 'TFACT'.

  gs_fieldcat-outputlen = '10'.

  append gs_fieldcat to gt_fieldcat.





endform.                    " build_catalog
