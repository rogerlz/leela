module Leela
  module Raw
    extend FFI::Library
    ffi_lib "leela"

    enum :status, [
      :leela_ok,       0,
      :leela_eof,      1,
      :leela_badargs,  2,
      :leela_timeout,  3,
      :leela_error,   -1
    ]

    enum :lql_row_type, [
      :lql_name_msg,
      :lql_path_msg,
      :lql_stat_msg,
      :lql_fail_msg,
      :lql_nattr_msg,
      :lql_kattr_msg,
      :lql_tattr_msg
    ]

    enum :lql_value_type, [
      :lql_nil_type,   -1,
      :lql_bool_type,   0,
      :lql_text_type,   1,
      :lql_int32_type,  2,
      :lql_int64_type,  3,
      :lql_uint32_type, 4,
      :lql_uint64_type, 5,
      :lql_double_type, 6
    ]

    attach_function :leela_lql_context_init, [:pointer, :string, :string, :int], :pointer
    attach_function :leela_lql_context_close, [:pointer], :status

    attach_function :leela_lql_cursor_init, [:pointer, :string, :string, :int], :pointer,  :blocking => true
    attach_function :leela_lql_cursor_execute, [:pointer, :string], :status,  :blocking => true

    attach_function :leela_lql_fetch_type, [:pointer], :lql_row_type

    attach_function :leela_endpoint_load,    [:string],  :pointer
    attach_function :leela_endpoint_free,    [:pointer], :void

    attach_function :leela_lql_fetch_name,   [:pointer], :pointer, :blocking => true
    attach_function :leela_lql_name_free,    [:pointer], :void

    attach_function :leela_lql_fetch_stat,   [:pointer], :pointer, :blocking => true
    attach_function :leela_lql_stat_free,    [:pointer], :void

    attach_function :leela_lql_fetch_path,   [:pointer], :pointer, :blocking => true
    attach_function :leela_lql_path_free,    [:pointer], :void

    attach_function :leela_lql_fetch_fail,   [:pointer], :pointer, :blocking => true
    attach_function :leela_lql_fail_free,    [:pointer], :void

    attach_function :leela_lql_cursor_next,  [:pointer], :status,  :blocking => true
    attach_function :leela_lql_cursor_close, [:pointer], :status,  :blocking => true

    attach_function :leela_lql_fetch_nattr, [:pointer], :pointer,  :blocking => true
    attach_function :leela_lql_nattr_free, [:pointer], :void

    attach_function :leela_lql_fetch_kattr, [:pointer], :pointer,  :blocking => true
    attach_function :leela_lql_kattr_free, [:pointer], :void

    attach_function :leela_lql_fetch_tattr, [:pointer], :pointer,  :blocking => true
    attach_function :leela_lql_tattr_free, [:pointer], :void

    def self.with_cursor(ctx, user, pass, timeout)
      cursor = Leela::Raw.leela_lql_cursor_init(ctx, user, pass, timeout)
      begin
        yield(cursor)
      ensure
        rc = leela_lql_cursor_close(cursor)
        Leela::LeelaError.raise_from_leela_status rc if (rc != :leela_ok)
      end
    end

    class LqlName < FFI::Struct
      layout :user, :string,
             :tree, :string,
             :kind, :string,
             :name, :string,
             :guid, :string
    end

    class LqlPath < FFI::Struct
      layout :size,    :int,
             :entries, :pointer
    end

    class LqlStat < FFI::Struct
      layout :size,  :int,
             :attrs, :pointer
    end

    class LqlFail < FFI::Struct
      layout :code,    :uint32,
             :message, :string
    end

    class LqlAttrs < FFI::Struct
      layout :first,   :pointer,
             :second,  :pointer,
             :fstfree, :pointer,
             :sndfree, :pointer
    end

    class LqlNAttr < FFI::Struct
      layout :size,  :int,
             :guid,  :string,
             :names, :pointer
    end

    class LqlValueU < FFI::Union
      layout :v_str,    :string,
             :v_i32,    :int32,
             :v_i64,    :int64,
             :v_u32,    :uint32,
             :v_u64,    :uint64,
             :v_bool,   :bool,
             :v_double, :double
    end

    class LqlValueT < FFI::Struct
      layout :vtype, :lql_value_type,
             :data,  LqlValueU
    end

    class LqlKAttr < FFI::Struct
      layout :guid,  :string,
             :name,  :string,
             :value, :pointer # LqlValueT
    end

    class LqlTAttr < FFI::Struct
      layout :guid,   :string,
             :name,   :string,
             :size,   :int,
             :series, :pointer #LqlAttrs
    end
  end
end
