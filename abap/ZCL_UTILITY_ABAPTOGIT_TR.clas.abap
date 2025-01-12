" Helper class to talk to SAP transport request and ABAP objects operations
CLASS ZCL_UTILITY_ABAPTOGIT_TR DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

PUBLIC SECTION.

    " latest and active version mode
    CONSTANTS: c_latest_version     TYPE string VALUE 'latest',
               c_active_version     TYPE string VALUE 'active'.

    " version information of an ABAP object to fetch file content
    TYPES: BEGIN OF ts_version_no,
           objname      TYPE versobjnam,
           objtype      TYPE versobjtyp,
           objversionno TYPE versno,
           END OF ts_version_no.
    TYPES: tty_version_no TYPE STANDARD TABLE OF ts_version_no.

    " type for communicating ABAP objects to sync to Git from SAP
    TYPES: BEGIN OF ts_commit_object,
            devclass    TYPE string,
            objname     TYPE string,
            objtype     TYPE string,
            objtype2    TYPE string,
            fugr        TYPE string,
            progcls     TYPE string,
            subc        TYPE string,
            delflag     TYPE string,
            verno       TYPE i,
            filecontent TYPE string,
           END OF ts_commit_object.
    TYPES: tty_commit_object TYPE TABLE OF ts_commit_object.

    " source lines of an ABAP object
    TYPES: tty_abaptext TYPE TABLE OF ABAPTXT255 INITIAL SIZE 0.

    " cache for function group to package name mappings
    TYPES: BEGIN OF ts_fugr_devclass,
            fugr        TYPE string,
            devclass    TYPE string,
           END OF ts_fugr_devclass.
    TYPES: tty_fugr_devclass TYPE TABLE OF ts_fugr_devclass.

    " constructor
    " io_objtelemetry - class object for telemetry
    " iv_methtelemetry - method name for telemetry
    " for telemetry, the method will be invoked with parameters iv_message as string (for message content) and iv_kind as string (for category)
    METHODS constructor
        IMPORTING
            io_objtelemetry     TYPE REF TO object OPTIONAL
            iv_methtelemetry    TYPE string OPTIONAL.

    " fetch ABAP objects from SAP to commit to Git for a TR
    " iv_trid - TR ID
    " iv_packagenames - package names to include in commit, separated by comma
    " ev_comment - commit comment
    " it_commit_objects - table of ABAP objects to commit to Git including name, type, file content, add/update/delete status
    METHODS get_tr_commit_objects
        IMPORTING
            iv_trid             TYPE string
            iv_packagenames     TYPE string
        EXPORTING
            ev_comment          TYPE string
        CHANGING
            it_commit_objects   TYPE tty_commit_object
        RETURNING VALUE(rv_success) TYPE string.

    " get ABAP object version number (to fetch specific version's code lines)
    " iv_objname - ABAP object name from table TADIR
    " iv_objtype - ABAP object type from table TADIR
    " iv_mode - active/latest version mode
    " iv_date/iv_time - date and time of versions no later than to select
    " iv_findtest - require to find test class of a product class if applicable
    " ev_version_no - count of versions selected
    " cht_objversions - object versions selected
    METHODS get_versions_no
        IMPORTING
            iv_objname      TYPE e071-obj_name
            iv_objtype      TYPE e071-object
            iv_mode         TYPE string
            iv_date         TYPE d OPTIONAL
            iv_time         TYPE t OPTIONAL
            iv_findtest     LIKE abap_true
        EXPORTING
            ev_version_no   TYPE i
        CHANGING
            cht_objversions TYPE tty_version_no OPTIONAL
        RETURNING VALUE(rv_success) TYPE string.

    " construct ABAP object code content
    " iv_objname - ABAP object name from table TADIR
    " iv_objtype - ABAP object type from table TADIR
    " it_objversions - object versions
    " et_filecontent - file content lines
    " ev_tclsname - test class name
    " ev_tclstype - test class type
    " et_tclsfilecontent - test class file content lines
    METHODS build_code_content
        IMPORTING
            iv_objname          TYPE e071-obj_name
            iv_objtype          TYPE e071-object
            it_objversions      TYPE tty_version_no
        EXPORTING
            et_filecontent      TYPE tty_abaptext
            ev_tclsname         TYPE string
            ev_tclstype         TYPE string
            et_tclsfilecontent  TYPE tty_abaptext
        RETURNING VALUE(rv_success) TYPE string.

    " construct ABAP data table object description content
    " iv_objname - ABAP object name from table TADIR
    " iv_version - object version
    " ev_filecontent - file content
    " et_filecontent - file content lines
    METHODS build_data_table_content
        IMPORTING
            iv_objname          TYPE e071-obj_name
            iv_version          TYPE versno
        EXPORTING
            ev_filecontent      TYPE string
            et_filecontent      TYPE tty_abaptext
        RETURNING VALUE(rv_success) TYPE string.

    " remark: OOB program RPDASC00 also dumps schema/PCR but takes background job privilege to run
    " and then fetch spools log from WRITE output and wait for job finish -- complicated and error prone
    " remark: upon releasing customizing TR the snapshot of schema/PCR is kept though SAP doesn't keep
    " all old versions, it's reliable to keep the snapshot as Git commit at the same time to reflect
    " what version the TR keeps and transports later

    " construct HR/payroll schema language code content
    " iv_schemaname - schema name
    " et_filecontent - schema code content lines
    METHODS build_schema_content_active
        IMPORTING
            iv_schemaname   TYPE string
        EXPORTING
            et_filecontent  TYPE tty_abaptext.

    " construct HR/payroll personnel calculation rule code content
    " iv_pcrname - PCR name
    " et_filecontent - PCR code content lines
    METHODS build_pcr_content_active
        IMPORTING
            iv_pcrname      TYPE string
        EXPORTING
            et_filecontent  TYPE tty_abaptext.

PROTECTED SECTION.

PRIVATE SECTION.

    CONSTANTS c_en TYPE spras VALUE 'E'.

    " structure for data table description
    TYPES: BEGIN OF ty_dd02v,
            tabname TYPE string,
            ddlanguage TYPE string,
            tabclass TYPE string,
            clidep TYPE string,
            ddtext TYPE string,
            mainflag TYPE string,
            contflag TYPE string,
            shlpexi TYPE string,
           END OF ty_dd02v.
    TYPES: BEGIN OF ty_data_table_field,
            fieldname TYPE string,
            keyflag TYPE string,
            rollname TYPE string,
            adminfield TYPE string,
            datatype TYPE string,
            leng TYPE i,
            decimals TYPE i,
            notnull TYPE string,
            ddtext TYPE string,
            domname TYPE string,
            shlporigin TYPE string,
            comptype TYPE string,
           END OF ty_data_table_field.
    TYPES: tty_data_table_field TYPE TABLE OF ty_data_table_field WITH DEFAULT KEY.
    TYPES: BEGIN OF ty_data_table_desc,
            dd02v TYPE ty_dd02v,
            dd03v TYPE tty_data_table_field,
           END OF ty_data_table_desc.

    " telemetry callback
    DATA oref_telemetry TYPE REF TO object.
    DATA method_name_telemetry TYPE string.

    " get function group name of an object in a function group
    METHODS get_fugr
        IMPORTING
            iv_objname  TYPE string
        EXPORTING
            ev_fugrname TYPE string.

    " get source code lines and count of them
    METHODS get_code_lines
        IMPORTING
            iv_version  TYPE versno
            iv_objname  TYPE versobjnam
            iv_objtype  TYPE versobjtyp
            iv_logdest  TYPE rfcdest
        EXPORTING
            linecount   TYPE i
            abaptext    TYPE tty_abaptext
        RETURNING VALUE(rv_success) TYPE string.

    " get source code lines for enhancement implementation
    METHODS get_code_lines_enho
        IMPORTING
            iv_version  TYPE versno
            iv_objname  TYPE versobjnam
            iv_logdest  TYPE rfcdest
        EXPORTING
            abaptext    TYPE tty_abaptext
        RETURNING VALUE(rv_success) TYPE string.

    " get class object version (for public/protected/private sections in definition and method implementations)
    METHODS get_class_versions_no
        IMPORTING
            iv_objname      TYPE e071-obj_name
            iv_objtype      TYPE e071-object
            iv_mode         TYPE string
            iv_date         TYPE d OPTIONAL
            iv_time         TYPE t OPTIONAL
            iv_findtest     LIKE abap_true DEFAULT abap_true
        CHANGING
            cht_objversions TYPE tty_version_no OPTIONAL
        RETURNING VALUE(r_version_no) TYPE i.

    " get valued version to no later than specific time stamp if any given latest/active version mode
    METHODS get_valued_version
        IMPORTING
            iv_mode     TYPE string
            iv_date     TYPE d OPTIONAL
            iv_time     TYPE t OPTIONAL
        EXPORTING
            ev_versno   TYPE versno
            ev_verscnt  TYPE i
        CHANGING
            cht_vers    TYPE vrsd_tab
        RETURNING VALUE(rv_success) TYPE string.

    " get versions of an ABAP object
    METHODS get_versions
        IMPORTING
            iv_objname      TYPE e071-obj_name
            iv_objtype      TYPE e071-object
        CHANGING
            it_vers         TYPE vrsd_tab
        RETURNING VALUE(rv_success) TYPE string.

    " get methods of a class object
    METHODS get_class_methods
        IMPORTING
            iv_classname    TYPE classname
        CHANGING
            cht_methods     TYPE abap_methdescr_tab.

    " wrapper to write telemetry with the callback registered
    METHODS write_telemetry
        IMPORTING
            iv_message  TYPE string
            iv_kind     TYPE string DEFAULT 'error'.

ENDCLASS.



CLASS ZCL_UTILITY_ABAPTOGIT_TR IMPLEMENTATION.

  METHOD CONSTRUCTOR.

    IF io_objtelemetry IS SUPPLIED.
        me->oref_telemetry = io_objtelemetry.
    ENDIF.

    IF iv_methtelemetry IS SUPPLIED.
        me->method_name_telemetry = iv_methtelemetry.
    ENDIF.

  ENDMETHOD.

  METHOD GET_TR_COMMIT_OBJECTS.

    DATA ld_cs_request TYPE TRWBO_REQUEST.
    DATA lv_trkorr TYPE TRKORR.
    FIELD-SYMBOLS <fs_cs_request_object> LIKE LINE OF ld_cs_request-objects.
    DATA lt_objversions TYPE tty_version_no.
    DATA lt_filecontent TYPE tty_abaptext.
    DATA lt_tclsfilecontent TYPE tty_abaptext.
    DATA lt_packagenames TYPE TABLE OF string.
    DATA lv_packagename TYPE string.
    DATA lv_objname2 TYPE string.
    DATA lv_objtype2 TYPE string.
    DATA lv_devclass TYPE string.
    DATA lv_fugr TYPE string.
    DATA lv_filecontent TYPE string.
    DATA lv_tclsname TYPE string.
    DATA lv_tclstype TYPE string.
    DATA lv_tclsfilecontent TYPE string.
    DATA lv_version_no TYPE i.
    DATA lv_funcname TYPE string.
    DATA lt_tasks TYPE TABLE OF string.
    DATA lt_commentlines TYPE TABLE OF string.
    DATA lt_taskids TYPE TABLE OF string.
    DATA lv_task TYPE string.
    DATA lv_taskid TYPE string.
    DATA lv_taskdesc TYPE string.
    DATA lt_taskfields TYPE TABLE OF string.
    DATA lt_tasktexts TYPE TABLE OF string.
    DATA lv_programm TYPE PROGRAMM.
    DATA lv_classkey TYPE SEOCLSKEY.
    DATA lv_classname TYPE tadir-obj_name.
    DATA lv_haspackage LIKE abap_true.
    DATA lt_objname_parts TYPE TABLE OF string.
    DATA lt_classes TYPE TABLE OF string.
    DATA lt_fugrs TYPE TABLE OF ts_fugr_devclass.
    DATA lv_cdate TYPE cdate.
    DATA lv_udate TYPE aedat.
    DATA lv_progcls TYPE t52ba-pwert.
    DATA lv_subc TYPE reposrc-subc.
    DATA lv_success TYPE string.

    rv_success = abap_true.

    " fetch objects in a TR
    lv_trkorr = iv_trid.
    CALL FUNCTION 'TR_READ_REQUEST'
      EXPORTING
        iv_read_e070 =               abap_true
        iv_read_e07t =               abap_true
        iv_read_e070c =              abap_true
        iv_read_e070m =              abap_true
        iv_read_objs_keys =          abap_true
        iv_read_attributes =         abap_true
        iv_trkorr =                  lv_trkorr
      CHANGING
        cs_request =                 ld_cs_request
      EXCEPTIONS
        ERROR_OCCURED =              1
        NO_AUTHORIZATION =           2.
    IF sy-subrc <> 0.
        me->write_telemetry( iv_message = |GET_TR_COMMIT_OBJECTS fails to call TR_READ_REQUEST with '{ lv_trkorr }' subrc { sy-subrc }| ).
        rv_success = abap_false.
        EXIT.
    ENDIF.

    " only support workbench/customizing TR
    IF ld_cs_request-h-trfunction <> 'K' AND ld_cs_request-h-trfunction <> 'W'.
        me->write_telemetry( iv_message = |GET_TR_COMMIT_OBJECTS meets request type '{ ld_cs_request-h-trfunction }'| ).
        rv_success = abap_false.
        EXIT.
    ENDIF.

    " only support released one
    IF ld_cs_request-h-trstatus <> 'R'.
        me->write_telemetry( iv_message = |GET_TR_COMMIT_OBJECTS meets request status '{ ld_cs_request-h-trstatus }'| ).
        rv_success = abap_false.
        EXIT.
    ENDIF.

    " construct Git commit description carrying TR ID, owner and original description
    " the Git commit can't has committer as the TR owner, instead, on-behalf-of the owner by user name/PAT specified
    APPEND |{ iv_trid }\|{ ld_cs_request-h-as4user }\|{ ld_cs_request-h-as4text }| TO lt_commentlines.

    " fetch tasks in a TR
    SELECT obj_name FROM e071 INTO TABLE @lt_tasks WHERE trkorr = @lv_trkorr AND object = 'RELE' AND pgmid = 'CORR'.

    " append all tasks' description to the commit description
    LOOP AT lt_tasks INTO lv_task.
        CLEAR lt_taskfields.
        SPLIT lv_task AT ' ' INTO TABLE lt_taskfields.
        lv_taskid = lt_taskfields[ 1 ].
        SELECT SINGLE as4text FROM e07t INTO @lv_taskdesc WHERE trkorr = @lv_taskid.
        APPEND |{ lv_task } { lv_taskdesc }| TO lt_tasktexts.
    ENDLOOP.

    APPEND LINES OF lt_tasktexts TO lt_commentlines.

    " commit description now contains TR description plus all tasks' description each line
    ev_comment = concat_lines_of( table = lt_commentlines sep = CL_ABAP_CHAR_UTILITIES=>CR_LF ).

    CLEAR: lt_taskids, lt_taskfields, lt_tasktexts.

    SPLIT iv_packagenames AT ',' INTO TABLE lt_packagenames.

    " process objects in the TR
    LOOP AT ld_cs_request-objects ASSIGNING <fs_cs_request_object> WHERE object <> 'RELE'.

        DATA(lv_objname) = <fs_cs_request_object>-obj_name.
        DATA(lv_objtype) = <fs_cs_request_object>-object.

        IF ld_cs_request-h-trfunction = 'W'.

            " schema/PCR object in customizing request

            lv_objname2 = lv_objname.
            IF lv_objtype = 'PSCC'.
                me->build_schema_content_active(
                    EXPORTING
                        iv_schemaname = lv_objname2
                    IMPORTING
                        et_filecontent = lt_filecontent
                         ).
                SELECT SINGLE cdate FROM t52cc INTO @lv_cdate WHERE sname = @lv_objname.
                SELECT SINGLE udate FROM t52cc INTO @lv_udate WHERE sname = @lv_objname.
            ELSEIF lv_objtype = 'PCYC'.
                me->build_pcr_content_active(
                    EXPORTING
                        iv_pcrname = lv_objname2
                    IMPORTING
                        et_filecontent = lt_filecontent
                         ).
                SELECT SINGLE cdate FROM t52ce INTO @lv_cdate WHERE cname = @lv_objname.
                SELECT SINGLE udate FROM t52ce INTO @lv_udate WHERE cname = @lv_objname.
                SELECT SINGLE pwert FROM t52ba INTO @lv_progcls WHERE potyp = 'CYCL' AND ponam = @lv_objname AND pattr = 'PCL'.
            ELSE.
                " me->write_telemetry( iv_message = |unsupported type { lv_objtype } for object { lv_objname }| iv_kind = 'info' ).
                CONTINUE.
            ENDIF.

            " schema/PCR has no reliable version upon releasing TR, have to use dates to determine add or update
            IF lv_udate IS INITIAL OR lv_cdate = lv_udate.
                lv_version_no = 1.
            ELSE.
                lv_version_no = 2.
            ENDIF.

            " stitch to string from source code lines
            lv_filecontent = concat_lines_of( table = lt_filecontent sep = CL_ABAP_CHAR_UTILITIES=>CR_LF ).

            TRANSLATE lv_objname TO UPPER CASE.

            APPEND VALUE ts_commit_object(
                devclass = ''
                objname = lv_objname
                objtype = lv_objtype
                objtype2 = lv_objtype
                fugr = ''
                progcls = lv_progcls
                delflag = abap_false
                verno = lv_version_no
                filecontent = lv_filecontent
                ) TO it_commit_objects.

        ELSE.

            " source code object in workbench request

            CLEAR: lv_objtype2, lv_devclass.

            IF lv_objtype = 'CINC'
                OR lv_objtype = 'CLSD'
                OR lv_objtype = 'CPUB'
                OR lv_objtype = 'CPRT'
                OR lv_objtype = 'CPRI'
                OR lv_objtype = 'METH'.

                " a test class, class definition, public/protected/private section and method will not be located in table tadir
                " need to find the product class it belongs to and then find the package the product class belongs to

                IF lv_objtype = 'CINC'.
                    " test class name to product class name
                    lv_programm = lv_objname.
                    CALL FUNCTION 'SEO_CLASS_GET_NAME_BY_INCLUDE'
                        EXPORTING
                            progname = lv_programm
                        IMPORTING
                            clskey = lv_classkey.
                    lv_classname = lv_classkey.
                ELSE.
                    IF lv_objtype = 'METH'.
                        " class name <spaces> method name pattern
                        CLEAR lt_objname_parts.
                        SPLIT lv_objname AT ' ' INTO TABLE lt_objname_parts.
                        lv_classname = lt_objname_parts[ 1 ].
                    ELSE.
                        " for CLSD/CPUB/CPRT/CPRI case class name is provided
                        lv_classname = lv_objname.
                    ENDIF.

                    IF line_exists( lt_classes[ table_line = lv_classname ] ).
                        " this class has been processed, skip
                        CONTINUE.
                    ELSE.
                        " use the class name instead and ensure it's processed only one time
                        APPEND lv_classname TO lt_classes.
                        lv_objname = lv_classname.
                        lv_objtype = 'CLAS'.
                    ENDIF.
                ENDIF.

                " find out which package the class belongs to
                SELECT SINGLE devclass INTO lv_devclass FROM tadir
                    WHERE object = 'CLAS' AND obj_name = lv_classname.

            ELSEIF lv_objtype = 'FUNC'.

                " function module case, find out function group and then the package function group belongs to
                lv_funcname = lv_objname.
                me->get_fugr( EXPORTING iv_objname = lv_funcname IMPORTING ev_fugrname = lv_fugr ).

                " use cache for function group objects
                IF line_exists( lt_fugrs[ fugr = lv_fugr ] ).
                    lv_devclass = lt_fugrs[ fugr = lv_fugr ]-devclass.
                ELSE.
                    SELECT SINGLE devclass FROM tadir INTO lv_devclass
                        WHERE obj_name = lv_fugr AND object = 'FUGR'.
                    APPEND VALUE ts_fugr_devclass( fugr = lv_fugr devclass = lv_devclass ) TO lt_fugrs.
                ENDIF.

            ELSEIF lv_objtype = 'REPS'.

                " could be repair of an object
                " need to search object type to replace 'REPS'
                SELECT SINGLE object FROM tadir INTO lv_objtype
                    WHERE obj_name = lv_objname.
                IF sy-subrc = 0.

                    " found, use the right type of the object
                    " find out which package the ABAP object belongs to
                    SELECT SINGLE devclass INTO lv_devclass FROM tadir
                        WHERE object = lv_objtype AND obj_name = lv_objname.

                ELSE.

                    " function include case, extract function group name and then the package function group belongs to
                    " function include name as L + function group name + 3 characters
                    IF strlen( lv_objname ) < 4.
                        lv_fugr = ''.
                    ELSE.
                        lv_fugr = substring( val = lv_objname off = 1 len = strlen( lv_objname ) - 1 - 3 ).
                    ENDIF.

                    " use cache for function group objects
                    IF line_exists( lt_fugrs[ fugr = lv_fugr ] ).
                        lv_devclass = lt_fugrs[ fugr = lv_fugr ]-devclass.
                    ELSE.
                        SELECT SINGLE devclass FROM tadir INTO lv_devclass
                            WHERE obj_name = lv_fugr AND object = 'FUGR'.
                        APPEND VALUE ts_fugr_devclass( fugr = lv_fugr devclass = lv_devclass ) TO lt_fugrs.
                    ENDIF.

                ENDIF.

            ELSEIF lv_objtype = 'PROG' OR lv_objtype = 'INTF' OR lv_objtype = 'ENHO'.

                " program (include), interface, enhancement implementation case

                " find out which package the ABAP object belongs to
                SELECT SINGLE devclass INTO lv_devclass FROM tadir
                    WHERE object = lv_objtype AND obj_name = lv_objname.

            ELSEIF lv_objtype = 'TABD'.

                " data table case

                " find out which package the ABAP object belongs to
                SELECT SINGLE devclass INTO lv_devclass FROM tadir
                    WHERE object = 'TABL' AND obj_name = lv_objname.

            ELSE.

                " me->write_telemetry( iv_message = |unsupported type { lv_objtype } for object { lv_objname }| iv_kind = 'info' ).
                CONTINUE.

            ENDIF.

            lv_haspackage = abap_true.
            IF sy-subrc <> 0.
                " the ABAP object is not found from tadir, it may be a deleted object
                lv_haspackage = abap_false.
            ENDIF.

            " fetch versions no later than given TR date/time
            CLEAR lt_objversions.
            lv_success = me->get_versions_no(
                EXPORTING
                    iv_objname = lv_objname
                    iv_objtype = lv_objtype
                    iv_mode = c_latest_version
                    iv_date = ld_cs_request-h-as4date
                    iv_time = ld_cs_request-h-as4time
                    iv_findtest = abap_false
                IMPORTING
                    ev_version_no = lv_version_no
                CHANGING
                    cht_objversions = lt_objversions
                    ).
            IF lv_success = abap_false AND lv_haspackage = abap_false.
                " can't locate this object in table tadir and versions neither
                " fail to find which package it belongs to and can't place it to ADO push payload
                me->write_telemetry( iv_message = |deleted object { lv_objname } type { lv_objtype } can't be processed without package name available| ).
                CONTINUE.
            ENDIF.

            " is the object in one of the packages specified?
            CHECK line_exists( lt_packagenames[ table_line = lv_devclass ] ).

            " is there any version found?
            CHECK lv_version_no > 0.

            " fetch function group name in case of function module
            IF lv_objtype = 'FUGR'.
                lv_funcname = lv_objname.
                lv_objtype2 = 'FUNC'.
                me->get_fugr( EXPORTING iv_objname = lv_funcname IMPORTING ev_fugrname = lv_fugr ).
            ENDIF.

            " construct object content (and test class content won't be provided given not required to in fetching version above)
            IF lv_objtype = 'TABL' OR lv_objtype = 'TABD'.
                rv_success = me->build_data_table_content(
                    EXPORTING
                        iv_objname = lv_objname
                        iv_version = lt_objversions[ 1 ]-objversionno
                    IMPORTING
                        ev_filecontent = lv_filecontent
                        ).
                CHECK rv_success = abap_true.
            ELSE.
                CLEAR lt_filecontent.
                CLEAR lt_tclsfilecontent.
                CLEAR lv_tclsfilecontent.
                rv_success = me->build_code_content(
                    EXPORTING
                        iv_objname = lv_objname
                        iv_objtype = lv_objtype
                        it_objversions = lt_objversions
                    IMPORTING
                        et_filecontent = lt_filecontent
                        ev_tclsname = lv_tclsname
                        ev_tclstype = lv_tclstype
                        et_tclsfilecontent = lt_tclsfilecontent
                        ).
                CHECK rv_success = abap_true.

                " stitch to string from source code lines
                lv_filecontent = concat_lines_of( table = lt_filecontent sep = CL_ABAP_CHAR_UTILITIES=>CR_LF ).
            ENDIF.

            IF lv_objtype = 'CINC'.
                " following abapGit where class name is used for test class name instead of ====CCAU like one
                lv_objname = lv_classname.
            ENDIF.

            CLEAR lv_subc.
            SELECT SINGLE subc FROM reposrc INTO @lv_subc WHERE progname = @lv_objname.

            TRANSLATE lv_objname TO UPPER CASE.

            APPEND VALUE ts_commit_object(
                devclass = lv_devclass
                objname = lv_objname
                objtype = lv_objtype
                objtype2 = lv_objtype2
                fugr = lv_fugr
                subc = lv_subc
                delflag = abap_false
                verno = lv_version_no
                filecontent = lv_filecontent
                ) TO it_commit_objects.

        ENDIF.

    ENDLOOP.

  ENDMETHOD.

  METHOD GET_FUGR.

    DATA lv_pname_filter TYPE string.
    SELECT SINGLE pname INTO @lv_pname_filter FROM tfdir WHERE funcname = @iv_objname.
    IF strlen( lv_pname_filter ) < 4.
        ev_fugrname = ''.
    ELSE.
        ev_fugrname = lv_pname_filter+4.    " SAPL... as prefix for names in pname field
    ENDIF.

  ENDMETHOD.

  METHOD GET_CODE_LINES.

      DATA: lv_no_release_transformation TYPE svrs_bool.
      DATA: trdir_new TYPE TABLE OF TRDIR INITIAL SIZE 1.
      DATA: smodilog_new TYPE table of smodilog.

      linecount = 0.

      IF iv_logdest = space OR iv_logdest = 'NONE'.
        lv_no_release_transformation = abap_true.
      ELSE.
        lv_no_release_transformation = abap_false.
      ENDIF.

      CALL FUNCTION 'SVRS_GET_REPS_FROM_OBJECT'
        EXPORTING
          destination                  = iv_logdest
          object_name                  = iv_objname
          object_type                  = iv_objtype
          versno                       = iv_version
          iv_no_release_transformation = lv_no_release_transformation
        TABLES
          repos_tab                    = abaptext
          trdir_tab                    = trdir_new
          vsmodilog                    = smodilog_new
        EXCEPTIONS
          no_version                   = 01.
      IF sy-subrc <> 0.
         me->write_telemetry( iv_message = |GET_CODE_LINES fails in fetching code lines for { iv_objname } type { iv_objtype } version { iv_version }| ).
         rv_success = abap_false.
         EXIT.
      ENDIF.

      linecount = lines( abaptext ).
      rv_success = abap_true.

  ENDMETHOD.

  METHOD GET_CODE_LINES_ENHO.

    DATA lv_enhancement_id TYPE ENHNAME.
    DATA r_vers TYPE REF TO IF_ENH_TOOL.
    DATA lv_state type r3state.
    DATA lv_tooltype TYPE enhtooltype.
    DATA:   l_clas_data   TYPE ENHCLASSMETHDATA,
            l_fugr_data   TYPE ENHFUGRDATA,
            l_hook_data   TYPE ENH_HOOK_ADMIN.

    rv_success = abap_false.

    lv_enhancement_id = iv_objname.

    TRY.
        CALL METHOD cl_enh_factory=>get_enhancement
            EXPORTING
                enhancement_id = lv_enhancement_id
                versno = iv_version
                rfcdestination = iv_logdest
            RECEIVING
                enhancement = r_vers.
    CATCH CX_ENH_IO_ERROR.
        EXIT.
    CATCH CX_ENH_ROOT.
        EXIT.
    ENDTRY.

    cl_enh_cache=>refresh_enh_cache( enhname = lv_enhancement_id ).
    lv_tooltype = r_vers->get_tool( ).

    lv_state = 'A'.

    CASE lv_tooltype.

        WHEN 'CLASENH' OR 'INTFENH'.
            TRY.
                CALL METHOD r_vers->if_enh_object~get_data
                    EXPORTING
                        version = lv_state
                    IMPORTING
                        DATA    = l_clas_data.
                APPEND LINES OF l_clas_data-enh_eimpsource TO abaptext.
                LOOP AT l_clas_data-enh_methsources INTO DATA(wa_enh_meth).
                    APPEND '' TO abaptext.
                    APPEND '' TO abaptext.
                    APPEND LINES OF wa_enh_meth-source TO abaptext.
                ENDLOOP.
                rv_success = abap_true.
            CATCH CX_ENH_NO_VALID_INPUT_TYPE .
                EXIT.
            ENDTRY.
        WHEN 'FUGRENH'.
            TRY.
                CALL METHOD r_vers->if_enh_object~get_data
                    EXPORTING
                        version = lv_state
                    IMPORTING
                        DATA    = l_fugr_data.
                " TODO function group case
            CATCH CX_ENH_NO_VALID_INPUT_TYPE .
                EXIT.
            ENDTRY.
        WHEN 'BADI_IMPL'.
            " BAdI case has no code to produce
        WHEN 'HOOK_IMPL'.
            TRY.
                CALL METHOD r_vers->if_enh_object~get_data
                    EXPORTING
                        version = lv_state
                    IMPORTING
                        DATA    = l_hook_data.
                 " stitch all enhancement ID source code lines to one file
                 LOOP AT l_hook_data-hook_impls INTO DATA(wa_hook_impl).
                    APPEND |ENHANCEMENT { wa_hook_impl-id } { iv_objname }.| TO abaptext.
                    APPEND LINES OF wa_hook_impl-source TO abaptext.
                    APPEND |ENDENHANCEMENT.| TO abaptext.
                 ENDLOOP.
                 APPEND '' TO abaptext.
                 rv_success = abap_true.
            CATCH CX_ENH_NO_VALID_INPUT_TYPE .
                EXIT.
            ENDTRY.
    ENDCASE.

  ENDMETHOD.

  METHOD BUILD_CODE_CONTENT.

    DATA lt_abaptext TYPE tty_abaptext.
    DATA lv_firstmethod TYPE c VALUE abap_true.
    DATA lv_linecount TYPE i.
    DATA lv_success TYPE string.
    DATA lv_hasmethod TYPE c VALUE abap_false.
    FIELD-SYMBOLS <fstxt> TYPE ABAPTXT255.
    DATA: textline TYPE string,
          abaptextline TYPE string.
    DATA: tclstextline TYPE string,
          tclsabaptextline TYPE string.

    rv_success = abap_true.

    " fetch code lines for each version object
    " for class object there may be multiple for methods, test class, public/protected/private sections
    " others only one
    LOOP AT it_objversions INTO DATA(waver).

        CLEAR lt_abaptext.

        IF waver-objtype = 'ENHO'.
            lv_success = me->get_code_lines_enho(
                EXPORTING
                    iv_version = waver-objversionno
                    iv_objname = waver-objname
                    iv_logdest = ''
                IMPORTING
                    abaptext = lt_abaptext
                    ).
        ELSE.
            lv_success = me->get_code_lines(
                EXPORTING
                    iv_version = waver-objversionno
                    iv_objname = waver-objname
                    iv_objtype = waver-objtype
                    iv_logdest = ''
                IMPORTING
                    linecount = lv_linecount
                    abaptext = lt_abaptext
                    ).
        ENDIF.
        IF lv_success = abap_false.
            rv_success = abap_false.
            EXIT.
        ENDIF.

        IF iv_objtype = 'CLAS'.
            " methods are added to class implementation clause
            IF waver-objtype = 'METH'.
                lv_hasmethod = abap_true.
                IF lv_firstmethod = abap_true.
                    textline = |ENDCLASS.|.
                    APPEND textline TO et_filecontent.
                    textline = ''.
                    APPEND textline TO et_filecontent.
                    textline = ''.
                    APPEND textline TO et_filecontent.
                    textline = |CLASS { iv_objname } IMPLEMENTATION.|.
                    APPEND textline TO et_filecontent.
                    textline = ''.
                    APPEND textline TO et_filecontent.
                ENDIF.
                lv_firstmethod = abap_false.
                LOOP AT lt_abaptext ASSIGNING <fstxt>.
                    abaptextline = <fstxt>.
                    textline = |{ abaptextline }|.
                    APPEND textline TO et_filecontent.
                ENDLOOP.
                textline = ''.
                APPEND textline TO et_filecontent.
            ELSEIF waver-objtype = 'CINC'.
                " test class is a stand-alone file to save
                ev_tclsname = waver-objname.
                ev_tclstype = waver-objtype.
                LOOP AT lt_abaptext ASSIGNING <fstxt>.
                    tclsabaptextline = <fstxt>.
                    tclstextline = |{ tclsabaptextline }|.
                    APPEND tclstextline TO et_tclsfilecontent.
                ENDLOOP.
            ELSE.
                LOOP AT lt_abaptext ASSIGNING <fstxt>.
                    abaptextline = <fstxt>.
                    textline = |{ abaptextline }|.
                    APPEND textline TO et_filecontent.
                ENDLOOP.
            ENDIF.
        ELSE.
            LOOP AT lt_abaptext ASSIGNING <fstxt>.
                abaptextline = <fstxt>.
                textline = |{ abaptextline }|.
                APPEND textline TO et_filecontent.
            ENDLOOP.
        ENDIF.
    ENDLOOP.

    CHECK rv_success = abap_true.

    " auto padding for class object at the end
    IF iv_objtype = 'CLAS'.
        textline = |ENDCLASS.|.
        APPEND textline TO et_filecontent.

        " class has no method lines, but class implementation portion should still be added.
        IF lv_hasmethod = abap_false.
            textline = ''.
            APPEND textline TO et_filecontent.
            textline = |CLASS { iv_objname } IMPLEMENTATION.|.
            APPEND textline TO et_filecontent.
            textline = |ENDCLASS.|.
            APPEND textline TO et_filecontent.
        ENDIF.
    ENDIF.

  ENDMETHOD.

  METHOD BUILD_DATA_TABLE_CONTENT.

    DATA:
        DD02TV_TAB TYPE TABLE OF DD02TV,
        DD02V_TAB TYPE TABLE OF DD02V,
        DD03TV_TAB TYPE TABLE OF DD03TV,
        DD03V_TAB TYPE TABLE OF DD03V,
        DD05V_TAB TYPE TABLE OF DD05V,
        DD08TV_TAB TYPE TABLE OF DD08TV,
        DD08V_TAB TYPE TABLE OF DD08V,
        DD35V_TAB TYPE TABLE OF DD35V,
        DD36V_TAB TYPE TABLE OF DD36V.
    DATA lv_objname TYPE VRSD-OBJNAME.
    DATA ls_data_table_desc TYPE ty_data_table_desc.
    DATA ls_data_table_field TYPE ty_data_table_field.

    rv_success = abap_false.

    lv_objname = iv_objname.
    CALL FUNCTION 'SVRS_GET_VERSION_TABD_40'
        EXPORTING
            object_name = lv_objname
            versno      = iv_version
        TABLES
            dd02v_tab   = dd02v_tab
            dd03v_tab   = dd03v_tab
            dd05v_tab   = dd05v_tab
            dd08v_tab   = dd08v_tab
            dd35v_tab   = dd35v_tab
            dd36v_tab   = dd36v_tab
            dd02tv_tab  = dd02tv_tab
            dd03tv_tab  = dd03tv_tab
            dd08tv_tab  = dd08tv_tab
        EXCEPTIONS
            no_version  = 01
            OTHERS = 02.
    IF sy-subrc <> 0.
       me->write_telemetry( iv_message = |BUILD_DATA_TABLE_CONTENT fails in fetching data table content for { iv_objname } version { iv_version }| ).
       EXIT.
    ENDIF.

    IF lines( dd02v_tab ) = 0.
       me->write_telemetry( iv_message = |BUILD_DATA_TABLE_CONTENT fails in fetching data table header for { iv_objname }| ).
       EXIT.
    ENDIF.

    ls_data_table_desc-dd02v-tabname = dd02v_tab[ 1 ]-tabname.
    ls_data_table_desc-dd02v-ddlanguage = dd02v_tab[ 1 ]-ddlanguage.
    ls_data_table_desc-dd02v-tabclass = dd02v_tab[ 1 ]-tabclass.
    ls_data_table_desc-dd02v-clidep = dd02v_tab[ 1 ]-clidep.
    ls_data_table_desc-dd02v-ddtext = dd02v_tab[ 1 ]-ddtext.
    ls_data_table_desc-dd02v-mainflag = dd02v_tab[ 1 ]-mainflag.
    ls_data_table_desc-dd02v-contflag = dd02v_tab[ 1 ]-contflag.
    ls_data_table_desc-dd02v-shlpexi = dd02v_tab[ 1 ]-shlpexi.

    LOOP AT dd03v_tab INTO DATA(wa_dd03v).
        CLEAR ls_data_table_field.
        ls_data_table_field-fieldname = wa_dd03v-fieldname.
        ls_data_table_field-keyflag = wa_dd03v-keyflag.
        ls_data_table_field-rollname = wa_dd03v-rollname.
        ls_data_table_field-adminfield = wa_dd03v-adminfield.
        ls_data_table_field-datatype = wa_dd03v-datatype.
        ls_data_table_field-leng = wa_dd03v-leng.
        ls_data_table_field-decimals = wa_dd03v-decimals.
        ls_data_table_field-notnull = wa_dd03v-notnull.
        ls_data_table_field-ddtext = wa_dd03v-ddtext.
        REPLACE ALL OCCURRENCES OF ',' IN ls_data_table_field-ddtext WITH '`'.
        ls_data_table_field-domname = wa_dd03v-domname.
        ls_data_table_field-shlporigin = wa_dd03v-shlporigin.
        ls_data_table_field-comptype = wa_dd03v-comptype.
        APPEND ls_data_table_field TO ls_data_table_desc-dd03v.
    ENDLOOP.

    /UI2/CL_JSON=>serialize(
        EXPORTING
            !data = ls_data_table_desc
            pretty_name = /ui2/cl_json=>pretty_mode-low_case
        RECEIVING
            r_json = ev_filecontent
             ).

    " beautify a bit with line breaks for code diff benefit
    REPLACE ALL OCCURRENCES OF ',' IN ev_filecontent WITH |,{ CL_ABAP_CHAR_UTILITIES=>CR_LF }|.
    REPLACE ALL OCCURRENCES OF '`' IN ls_data_table_field-ddtext WITH ','.

    SPLIT ev_filecontent AT CL_ABAP_CHAR_UTILITIES=>CR_LF INTO TABLE et_filecontent.

    rv_success = abap_true.

  ENDMETHOD.

  METHOD BUILD_SCHEMA_CONTENT_ACTIVE.

    TYPES ts_comment TYPE t52c3.
    DATA lv_ltext TYPE t52cc_t-ltext.
    DATA ls_desc TYPE t52cc.
    DATA lt_comments TYPE TABLE OF ts_comment.
    DATA lv_line TYPE c LENGTH 79.
    DATA lv_text TYPE string.

    " fetch schema's meta data
    SELECT SINGLE * FROM t52cc INTO @ls_desc WHERE sname = @iv_schemaname.

    " fetch schema's description text
    SELECT SINGLE ltext FROM t52cc_t INTO @lv_ltext WHERE sname = @iv_schemaname.

    " meta data for this schema, don't want to bother to add an additional XML/JSON description file
    APPEND |* Schema                : { iv_schemaname }| TO et_filecontent.
    APPEND |* Description           : { lv_ltext }| TO et_filecontent.
    APPEND |* Executable            : { ls_desc-execu }| TO et_filecontent.
    APPEND |* Owner                 : { ls_desc-respu }| TO et_filecontent.
    APPEND |* Creation Date         : { ls_desc-cdate }| TO et_filecontent.
    APPEND |* Only Changed by Owner : { ls_desc-execu }| TO et_filecontent.
    APPEND |* Version               : { ls_desc-uvers }| TO et_filecontent.
    APPEND |* Last Changed By       : { ls_desc-uname }| TO et_filecontent.
    APPEND |* Last Changed Date     : { ls_desc-udate }| TO et_filecontent.
    APPEND |* Last Changed Time     : { ls_desc-utime }| TO et_filecontent.

    " instruction table header
    APPEND 'Line   Func. Par1  Par2  Par3  Par4  D Text' TO et_filecontent.

    " fetch schema instructions' comments
    SELECT * FROM t52c3 INTO TABLE @lt_comments
        WHERE schem = @iv_schemaname AND spras = @c_en.

    " fetch schema instructions
    SELECT * FROM t52c1 INTO @DATA(wa_instr) WHERE schem = @iv_schemaname.
        CLEAR lv_line.
        lv_line = '000000'.
        lv_text = |{ wa_instr-seqno }|.
        DATA(len) = strlen( lv_text ).
        DATA(off) = 5 - len.
        lv_line+off(len) = lv_text.
        lv_line+7 = wa_instr-funco.
        lv_line+13 = wa_instr-parm1.
        lv_line+19 = wa_instr-parm2.
        lv_line+25 = wa_instr-parm3.
        lv_line+31 = wa_instr-parm4.
        lv_line+37 = wa_instr-delet.
        lv_line+39 = lt_comments[ seqno = wa_instr-textid ]-scdes.
        APPEND lv_line TO et_filecontent.
    ENDSELECT.

  ENDMETHOD.

  METHOD BUILD_PCR_CONTENT_ACTIVE.

    DATA lv_line TYPE c LENGTH 100.
    DATA lv_index TYPE i.
    DATA lv_text TYPE string.
    DATA lv_t TYPE c.
    DATA lv_ltext TYPE t52ce_t-ltext.
    DATA ls_desc TYPE t52ce.
    DATA lv_esg TYPE string.
    DATA lv_wgt TYPE string.
    DATA lv_cnt TYPE t52ba-pwert.
    DATA lv_first TYPE c VALUE abap_true.

    " fetch PCR's meta data
    SELECT SINGLE * FROM t52ce INTO @ls_desc WHERE cname = @iv_pcrname.
    SELECT SINGLE pwert FROM t52ba INTO @lv_cnt WHERE potyp = 'CYCL' AND ponam = @iv_pcrname AND pattr = 'CNT'.

    " fetch PCR's description text
    SELECT SINGLE ltext FROM t52ce_t INTO @lv_ltext WHERE cname = @iv_pcrname AND sprsl = @c_en.

    " meta data for this PCR, don't want to bother to add an additional XML/JSON description file
    APPEND |* PCR                   : { iv_pcrname }| TO et_filecontent.
    APPEND |* Description           : { lv_ltext }| TO et_filecontent.
    APPEND |* Country Grouping      : { lv_cnt }| TO et_filecontent.
    APPEND |* Owner                 : { ls_desc-respu }| TO et_filecontent.
    APPEND |* Creation Date         : { ls_desc-cdate }| TO et_filecontent.
    APPEND |* Only Changed by Owner : { ls_desc-relea }| TO et_filecontent.
    APPEND |* Last Changed By       : { ls_desc-uname }| TO et_filecontent.
    APPEND |* Last Changed Date     : { ls_desc-udate }| TO et_filecontent.
    APPEND |* Last Changed Time     : { ls_desc-utime }| TO et_filecontent.

    " fetch PCR instructions
    lv_index = 1.
    SELECT * FROM t52c5 INTO @DATA(wa_instr) WHERE ccycl = @iv_pcrname.
        IF lv_first = abap_true OR wa_instr-abart <> lv_esg OR wa_instr-lgart <> lv_wgt.
            APPEND '' TO et_filecontent.
            " show ES group and wage type
            APPEND |* ES Group { wa_instr-abart }, Wage/Time Type { wa_instr-lgart }| TO et_filecontent.
            " instruction table header
            APPEND 'Line   Var.Key CL T Operation  Operation  Operation  Operation  Operation  Operation *' TO et_filecontent.
            lv_first = abap_false.
            lv_esg = wa_instr-abart.
            lv_wgt = wa_instr-lgart.
            lv_index = 1.
        ENDIF.

        CLEAR lv_line.
        lv_line = '000000'.
        lv_text = |{ lv_index }|.
        DATA(len) = strlen( lv_text ).
        DATA(off) = 5 - len.
        lv_line+off(len) = lv_text.
        lv_line+7 = wa_instr-vargt.
        lv_line+15 = wa_instr-seqno.
        lv_text = wa_instr-vinfo.
        IF strlen( lv_text ) > 0.
            lv_t = lv_text+0(1).
            lv_text = lv_text+1.
        ELSE.
            lv_t = space.
        ENDIF.
        lv_line+18 = lv_t.
        lv_line+20 = lv_text.
        APPEND lv_line TO et_filecontent.
        lv_index = lv_index + 1.
    ENDSELECT.

  ENDMETHOD.

  METHOD GET_VERSIONS_NO.

    DATA wa_ver TYPE VRSD.
    DATA lt_vers TYPE vrsd_tab.
    DATA wa_objversion TYPE ts_version_no.
    DATA lv_versno TYPE versno.

    IF iv_objtype = 'FUNC'.
        " function module case
        CLEAR lt_vers.
        rv_success = me->get_versions(
            EXPORTING
                iv_objname = iv_objname
                iv_objtype = 'FUNC'
            CHANGING
                it_vers = lt_vers
                 ).
        CHECK rv_success = abap_true.
        rv_success = me->get_valued_version(
            EXPORTING
                iv_mode = iv_mode
                iv_date = iv_date
                iv_time = iv_time
            IMPORTING
                ev_versno = lv_versno
                ev_verscnt = ev_version_no
            CHANGING
                cht_vers = lt_vers
                 ).
        IF rv_success = abap_true AND cht_objversions IS SUPPLIED.
            wa_objversion-objversionno = lv_versno.
            wa_objversion-objname = iv_objname.
            wa_objversion-objtype = 'FUNC'.
            APPEND wa_objversion TO cht_objversions.
        ENDIF.
    ELSEIF iv_objtype = 'CLAS'.
        " class object case, multiple versions may return including public/protected/private sections and methods
        " if test class required, its versions will be fetched together
        ev_version_no = me->get_class_versions_no(
            EXPORTING
                iv_objname = iv_objname
                iv_objtype = iv_objtype
                iv_mode = iv_mode
                iv_date = iv_date
                iv_time = iv_time
                iv_findtest = iv_findtest
            CHANGING
                cht_objversions = cht_objversions
                 ).
        rv_success = abap_true.
    ELSEIF iv_objtype = 'CINC'.
        " in TR commit scenario test class will be requested separately
        CLEAR lt_vers.
        rv_success = me->get_versions(
            EXPORTING
                iv_objname = iv_objname
                iv_objtype = 'CINC'
            CHANGING
                it_vers = lt_vers
                 ).
        CHECK rv_success = abap_true.
        rv_success = me->get_valued_version(
            EXPORTING
                iv_mode = iv_mode
                iv_date = iv_date
                iv_time = iv_time
            IMPORTING
                ev_versno = lv_versno
                ev_verscnt = ev_version_no
            CHANGING
                cht_vers = lt_vers
                 ).
        IF rv_success = abap_true AND cht_objversions IS SUPPLIED.
            wa_objversion-objversionno = lv_versno.
            wa_objversion-objname = iv_objname.
            wa_objversion-objtype = 'CINC'.
            APPEND wa_objversion TO cht_objversions.
        ENDIF.
    ELSEIF iv_objtype = 'PROG'.
        " program/include case
        CLEAR lt_vers.
        rv_success = me->get_versions(
            EXPORTING
                iv_objname = iv_objname
                iv_objtype = 'REPS'
            CHANGING
                it_vers = lt_vers
                 ).
        CHECK rv_success = abap_true.
        rv_success = me->get_valued_version(
            EXPORTING
                iv_mode = iv_mode
                iv_date = iv_date
                iv_time = iv_time
            IMPORTING
                ev_versno = lv_versno
                ev_verscnt = ev_version_no
            CHANGING
                cht_vers = lt_vers
                 ).
        IF rv_success = abap_true AND cht_objversions IS SUPPLIED.
            wa_objversion-objversionno = lv_versno.
            wa_objversion-objname = iv_objname.
            wa_objversion-objtype = 'REPS'.
            APPEND wa_objversion TO cht_objversions.
        ENDIF.
    ELSEIF iv_objtype = 'REPS'.
        " include case
        CLEAR lt_vers.
        rv_success = me->get_versions(
            EXPORTING
                iv_objname = iv_objname
                iv_objtype = 'REPS'
            CHANGING
                it_vers = lt_vers
                 ).
        CHECK rv_success = abap_true.
        rv_success = me->get_valued_version(
            EXPORTING
                iv_mode = iv_mode
                iv_date = iv_date
                iv_time = iv_time
            IMPORTING
                ev_versno = lv_versno
                ev_verscnt = ev_version_no
            CHANGING
                cht_vers = lt_vers
                 ).
        IF rv_success = abap_true AND cht_objversions IS SUPPLIED.
            wa_objversion-objversionno = lv_versno.
            wa_objversion-objname = iv_objname.
            wa_objversion-objtype = 'REPS'.
            APPEND wa_objversion TO cht_objversions.
        ENDIF.
    ELSEIF iv_objtype = 'INTF'.
        " interface case
        CLEAR lt_vers.
        rv_success = me->get_versions(
            EXPORTING
                iv_objname = iv_objname
                iv_objtype = 'INTF'
            CHANGING
                it_vers = lt_vers
                 ).
        CHECK rv_success = abap_true.
        rv_success = me->get_valued_version(
            EXPORTING
                iv_mode = iv_mode
                iv_date = iv_date
                iv_time = iv_time
            IMPORTING
                ev_versno = lv_versno
                ev_verscnt = ev_version_no
            CHANGING
                cht_vers = lt_vers
                 ).
        IF rv_success = abap_true AND cht_objversions IS SUPPLIED.
            wa_objversion-objversionno = lv_versno.
            wa_objversion-objname = iv_objname.
            wa_objversion-objtype = 'INTF'.
            APPEND wa_objversion TO cht_objversions.
        ENDIF.
    ELSEIF iv_objtype = 'ENHO'.
        " enhancement implementation case
        CLEAR lt_vers.
        rv_success = me->get_versions(
            EXPORTING
                iv_objname = iv_objname
                iv_objtype = 'ENHO'
            CHANGING
                it_vers = lt_vers
                 ).
        CHECK rv_success = abap_true.
        rv_success = me->get_valued_version(
            EXPORTING
                iv_mode = iv_mode
                iv_date = iv_date
                iv_time = iv_time
            IMPORTING
                ev_versno = lv_versno
                ev_verscnt = ev_version_no
            CHANGING
                cht_vers = lt_vers
                 ).
        IF rv_success = abap_true AND cht_objversions IS SUPPLIED.
            wa_objversion-objversionno = lv_versno.
            wa_objversion-objname = iv_objname.
            wa_objversion-objtype = 'ENHO'.
            APPEND wa_objversion TO cht_objversions.
        ENDIF.
    ELSEIF iv_objtype = 'TABL' OR iv_objtype = 'TABD'.
        " data table case
        CLEAR lt_vers.
        rv_success = me->get_versions(
            EXPORTING
                iv_objname = iv_objname
                iv_objtype = 'TABD'
            CHANGING
                it_vers = lt_vers
                 ).
        CHECK rv_success = abap_true.
        rv_success = me->get_valued_version(
            EXPORTING
                iv_mode = iv_mode
                iv_date = iv_date
                iv_time = iv_time
            IMPORTING
                ev_versno = lv_versno
                ev_verscnt = ev_version_no
            CHANGING
                cht_vers = lt_vers
                 ).
        IF rv_success = abap_true AND cht_objversions IS SUPPLIED.
            wa_objversion-objversionno = lv_versno.
            wa_objversion-objname = iv_objname.
            wa_objversion-objtype = 'TABD'.
            APPEND wa_objversion TO cht_objversions.
        ENDIF.
    ELSE.
        rv_success = abap_false.
        ev_version_no = 0.
    ENDIF.

  ENDMETHOD.

  METHOD GET_VALUED_VERSION.

    DATA lv_mode TYPE string.
    lv_mode = iv_mode.
    TRANSLATE lv_mode TO LOWER CASE.

    SORT cht_vers DESCENDING BY versno.

    IF iv_date IS SUPPLIED AND iv_time IS SUPPLIED AND iv_date IS NOT INITIAL AND iv_time IS NOT INITIAL.
        " remove version later than given time, keep active/inactive version
        DELETE cht_vers WHERE versno <> 0 AND versno <> 99999 AND ( datum > iv_date OR ( datum = iv_date AND zeit > iv_time ) ).
    ENDIF.

    IF lines( cht_vers ) = 0.
        rv_success = abap_false.
        EXIT.
    ENDIF.

    IF lv_mode = c_latest_version.
        " exclude active/inactive version
        DELETE cht_vers WHERE versno = 0 OR versno = 99999.
        ev_verscnt = lines( cht_vers ).
        IF ev_verscnt = 0.
            " no latest released version available
            rv_success = abap_false.
            EXIT.
        ELSE.
            " at least one released version available, use it
            ev_versno = cht_vers[ 1 ]-versno.
            rv_success = abap_true.
        ENDIF.
    ELSEIF lv_mode = c_active_version.
        " exclude inactive version
        DELETE cht_vers WHERE versno = 99999.
        ev_verscnt = lines( cht_vers ).
        IF line_exists( cht_vers[ versno = 0 ] ).
            " active version available, use it
            ev_versno = 0.
            rv_success = abap_true.
        ELSE.
            " use latest released version since active one unavailable
            ev_versno = cht_vers[ 1 ]-versno.
            rv_success = abap_true.
        ENDIF.
    ELSE.
        me->write_telemetry( iv_message = |invalid mode { iv_mode }| ).
        rv_success = abap_false.
    ENDIF.

  ENDMETHOD.

  METHOD GET_CLASS_VERSIONS_NO.

    DATA lv_versno TYPE versno.
    DATA lv_verscnt TYPE i.
    DATA lv_objname TYPE e071-obj_name.
    DATA lv_classname TYPE classname.
    DATA lt_methods TYPE abap_methdescr_tab.
    DATA lv_methodname TYPE versobjnam.
    DATA wa_ver TYPE VRSD.
    DATA lt_vers TYPE vrsd_tab.
    DATA wa_objversion TYPE ts_version_no.
    FIELD-SYMBOLS <fsmethod> LIKE LINE OF lt_methods.
    DATA lv_CLSKEY TYPE SEOCLSKEY.
    DATA lv_LIMU TYPE SEOK_LIMU.
    DATA lv_INCTYPE TYPE CHAR3.
    DATA lv_progm TYPE PROGRAMM.
    DATA lv_testclassname TYPE versobjnam.
    DATA lv_success TYPE string.

    lv_classname = iv_objname.
    r_version_no = 1.

    " public section's version
    CLEAR lt_vers.
    me->get_versions(
        EXPORTING
            iv_objname = iv_objname
            iv_objtype = 'CPUB'
        CHANGING
            it_vers = lt_vers
             ).
    lv_success = me->get_valued_version(
        EXPORTING
            iv_mode = iv_mode
            iv_date = iv_date
            iv_time = iv_time
        IMPORTING
            ev_versno = lv_versno
            ev_verscnt = lv_verscnt
        CHANGING
            cht_vers = lt_vers
             ).
    IF lv_success = abap_true AND cht_objversions IS SUPPLIED.
        wa_objversion-objversionno = lv_versno.
        wa_objversion-objname = iv_objname.
        wa_objversion-objtype = 'CPUB'.
        APPEND wa_objversion TO cht_objversions.
    ENDIF.
    IF lv_verscnt > r_version_no.
        r_version_no = lv_verscnt.
    ENDIF.

    " protected section's version
    CLEAR lt_vers.
    me->get_versions(
        EXPORTING
            iv_objname = iv_objname
            iv_objtype = 'CPRT'
        CHANGING
            it_vers = lt_vers
             ).
    lv_success = me->get_valued_version(
        EXPORTING
            iv_mode = iv_mode
            iv_date = iv_date
            iv_time = iv_time
        IMPORTING
            ev_versno = lv_versno
            ev_verscnt = lv_verscnt
        CHANGING
            cht_vers = lt_vers
             ).
    IF lv_success = abap_true AND cht_objversions IS SUPPLIED.
        wa_objversion-objversionno = lv_versno.
        wa_objversion-objname = iv_objname.
        wa_objversion-objtype = 'CPRT'.
        APPEND wa_objversion TO cht_objversions.
    ENDIF.
    IF lv_verscnt > r_version_no.
        r_version_no = lv_verscnt.
    ENDIF.

    " private section's version
    CLEAR lt_vers.
    me->get_versions(
        EXPORTING
            iv_objname = iv_objname
            iv_objtype = 'CPRI'
        CHANGING
            it_vers = lt_vers
             ).
    lv_success = me->get_valued_version(
        EXPORTING
            iv_mode = iv_mode
            iv_date = iv_date
            iv_time = iv_time
        IMPORTING
            ev_versno = lv_versno
            ev_verscnt = lv_verscnt
        CHANGING
            cht_vers = lt_vers
             ).
    IF lv_success = abap_true AND cht_objversions IS SUPPLIED.
        wa_objversion-objversionno = lv_versno.
        wa_objversion-objname = iv_objname.
        wa_objversion-objtype = 'CPRI'.
        APPEND wa_objversion TO cht_objversions.
    ENDIF.
    IF lv_verscnt > r_version_no.
        r_version_no = lv_verscnt.
    ENDIF.

    " each method's version
    me->get_class_methods(
        EXPORTING
            iv_classname = lv_classname
        CHANGING
            cht_methods = lt_methods
             ).
    LOOP AT lt_methods ASSIGNING <fsmethod>.
        lv_methodname(30) = lv_classname.
        lv_methodname+30  = <fsmethod>-name.
        CLEAR lt_vers.
        lv_objname = lv_methodname.
        me->get_versions(
            EXPORTING
                iv_objname = lv_objname
                iv_objtype = 'METH'
            CHANGING
                it_vers = lt_vers
                 ).
        lv_success = me->get_valued_version(
            EXPORTING
                iv_mode = iv_mode
                iv_date = iv_date
                iv_time = iv_time
            IMPORTING
                ev_versno = lv_versno
                ev_verscnt = lv_verscnt
            CHANGING
                cht_vers = lt_vers
                 ).
        IF lv_success = abap_true AND cht_objversions IS SUPPLIED.
            wa_objversion-objversionno = lv_versno.
            wa_objversion-objname = lv_methodname.
            wa_objversion-objtype = 'METH'.
            APPEND wa_objversion TO cht_objversions.
        ENDIF.
        IF lv_verscnt > r_version_no.
            r_version_no = lv_verscnt.
        ENDIF.
    ENDLOOP.

    IF iv_findtest = abap_true.

        " test class of the class if any
        lv_CLSKEY = lv_classname.
        lv_LIMU = 'CINC'.
        lv_INCTYPE = 'AU'.
        CALL FUNCTION 'SEO_CLASS_GET_INCLUDE_BY_NAME'
            EXPORTING
                clskey = lv_CLSKEY
                limu = lv_LIMU
                inctype = lv_INCTYPE
            IMPORTING
                progname = lv_progm.

        lv_testclassname = lv_progm.

        lv_objname = lv_testclassname.
        CLEAR lt_vers.
        me->get_versions(
            EXPORTING
                iv_objname = lv_objname
                iv_objtype = 'CINC'
            CHANGING
                it_vers = lt_vers
                 ).
        lv_success = me->get_valued_version(
            EXPORTING
                iv_mode = iv_mode
                iv_date = iv_date
                iv_time = iv_time
            IMPORTING
                ev_versno = lv_versno
                ev_verscnt = lv_verscnt
            CHANGING
                cht_vers = lt_vers
                 ).
        IF lv_success = abap_true AND cht_objversions IS SUPPLIED.
            wa_objversion-objversionno = lv_versno.
            wa_objversion-objname = lv_objname.
            wa_objversion-objtype = 'CINC'.
            APPEND wa_objversion TO cht_objversions.
        ENDIF.
        IF lv_verscnt > r_version_no.
            r_version_no = lv_verscnt.
        ENDIF.

    ENDIF.

  ENDMETHOD.

  METHOD GET_CLASS_METHODS.

    DATA: lcl_obj TYPE REF TO cl_abap_objectdescr,
          lp_descr_ref TYPE REF TO CL_ABAP_TYPEDESCR.
    TRY.
        cl_abap_objectdescr=>describe_by_name(
            EXPORTING
                p_name = iv_classname
            RECEIVING
                P_DESCR_REF = lp_descr_ref
            EXCEPTIONS
                TYPE_NOT_FOUND = 1
                ).
        IF sy-subrc = 0.
            lcl_obj ?= lp_descr_ref.
            cht_methods = lcl_obj->methods.
        ENDIF.
    CATCH CX_SY_RTTI_SYNTAX_ERROR.
        me->write_telemetry( iv_message = |GET_CLASS_METHODS fails in fetching class methods for class { iv_classname }| ).
    ENDTRY.

  ENDMETHOD.

  METHOD GET_VERSIONS.

      DATA: lv_rfcdest TYPE RFCDEST,
            lt_versno TYPE STANDARD TABLE OF vrsn,
            lt_text_vers TYPE TABLE OF e07t,
            lt_vers_obj  TYPE TABLE OF vrsd,
            lt_text_obj TYPE TABLE OF e07t,
            lv_objname TYPE versobjnam,
            lv_objtype TYPE versobjtyp.

      lv_objname = iv_objname.
      lv_objtype = iv_objtype.

      CALL FUNCTION 'SVRS_GET_VERSION_DIRECTORY_46'
        EXPORTING
          destination  = lv_rfcdest
          objtype      = lv_objtype
          objname      = lv_objname
        TABLES
          lversno_list = lt_versno
          version_list = it_vers
        EXCEPTIONS
          no_entry     = 1
          OTHERS       = 2.
      IF sy-subrc <> 0.
        " a class method may not have entry thus sy-subrc as 1
        " other exceptions should be reported
        IF sy-subrc <> 1.
            me->write_telemetry( iv_message = |GET_VERSIONS fails with { lv_objname } { lv_objtype } subrc { sy-subrc }| ).
            rv_success = abap_false.
            EXIT.
        ENDIF.
      ENDIF.

      CALL FUNCTION 'GET_E07T_DATA_46'
        EXPORTING
          destination           = lv_rfcdest
          mode                  = 'V'
        TABLES
          version_list          = it_vers
          e07t_vrs              = lt_text_vers
          e07t_obj              = lt_text_obj
          object_list           = lt_vers_obj
        EXCEPTIONS
          system_failure        = 1
          communication_failure = 2.
      IF sy-subrc <> 0.
        me->write_telemetry( iv_message = |GET_VERSIONS fails in calling GET_E07T_DATA_46 subrc { sy-subrc }| ).
        rv_success = abap_false.
        EXIT.
      ENDIF.

      rv_success = abap_true.

  ENDMETHOD.

  METHOD WRITE_TELEMETRY.
    IF me->oref_telemetry IS NOT INITIAL AND me->method_name_telemetry IS NOT INITIAL.
        DATA(oref) = me->oref_telemetry.
        DATA(meth) = me->method_name_telemetry.
        CALL METHOD oref->(meth)
            EXPORTING
                iv_message = iv_message
                iv_kind = iv_kind.
    ELSE.
        WRITE / |{ iv_kind }: { iv_message }|.
    ENDIF.
  ENDMETHOD.

ENDCLASS.