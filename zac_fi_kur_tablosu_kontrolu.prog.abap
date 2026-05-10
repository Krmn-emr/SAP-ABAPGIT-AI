*&---------------------------------------------------------------------*
*&  Include           ZAC_FI_KUR_TABLOSU_KONTROLU
*&---------------------------------------------------------------------*

DATA : lt_fr_fm TYPE fbname,
       lw_fr_fm TYPE rs38l_fnam.


call function 'Z_W0_USEREXIT_CHECK'
  exporting
    p_include   = 'ZAC_FI_KUR_TABLOSU_KONTROLU'
    p_key1      = 'ASD'
    p_val1      = space
  changing
    func_module = lt_fr_fm
  exceptions
    not_active  = 1
    others      = 2.

if sy-subrc eq 0.
  tables: tcurr,
          zfi_tkur,
          zac_fi_kur.
  "zsd_kur_user.

  data: it_zfi_tkur like zfi_tkur occurs 0 with header line,
        it_zac_fi_kur like zac_fi_kur occurs 0 with header line,
        error(1),
        lv_date(10),
        datum like v_tcurr-gdatu,
        metin(250),
        tarih(10).

  clear error.


  write sy-datum to lv_date dd/mm/yyyy.
  call function 'CONVERSION_EXIT_INVDT_INPUT'
    exporting
      input  = lv_date
    importing
      output = datum.


*       FI Kur kontrolü | begin
  select single * from zac_fi_kur where etkin eq 'X'
                                   and bname eq sy-uname.
  check sy-subrc is initial.
  select * from zfi_tkur into table it_zfi_tkur.
  loop at it_zfi_tkur.
    select single * from tcurr where kurst eq 'M'
                                 and fcurr eq it_zfi_tkur-fcurr
                                 and tcurr eq 'TRY'
                                 and gdatu eq datum.
    if sy-subrc ne 0.
      error = 1.
    endif.
  endloop.
  if sy-subrc ne 0.
    error = 1.
  endif.
  "   Hata ver
  check error = 1.
  concatenate  lv_date 'tarihine ilişkin kur bakımı yapılmamış.'
    into metin separated by space.
  message metin type 'I' display like 'E'.

  "   Kur transaction'ının çalıştır
  check zac_fi_kur-etkin2 eq 'X'.
  call transaction 'ZAC_FI002'.

*       FI Kur kontrolü | end
endif.
