require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "Net::SNMP::Wrapper" do
  def init_session
    community = "demopublic"
    peername = "test.net-snmp.org"
    
    sess = Net::SNMP::Wrapper::SnmpSession.new
    Net::SNMP::Wrapper.snmp_sess_init(sess.pointer)
    sess.community = FFI::MemoryPointer.new(:pointer, community.length + 1)
    sess.community.write_string(community)
    sess.community_len = community.length
    sess.peername = FFI::MemoryPointer.new(:pointer, peername.length + 1)
    sess.peername.write_string(peername)
    sess.version = Net::SNMP::SNMP_VERSION_1
    sess
  end

  def make_pdu
    pdu_ptr = Net::SNMP::Wrapper.snmp_pdu_create(Net::SNMP::SNMP_MSG_GET)
    pdu = Net::SNMP::Wrapper::SnmpPdu.new(pdu_ptr)
    anOID = FFI::MemoryPointer.new(:ulong, Net::SNMP::MAX_OID_LEN)
    anOIDLen = FFI::MemoryPointer.new(:size_t)
    anOIDLen.write_int(Net::SNMP::MAX_OID_LEN)
    Net::SNMP::Wrapper.snmp_parse_oid("sysDescr.0", anOID, anOIDLen)
    Net::SNMP::Wrapper.snmp_add_null_var(pdu.pointer, anOID, anOIDLen.read_int)
    pdu
  end

  it "wrapper should snmpget synchronously" do

    sess = init_session
    sess = Net::SNMP::Wrapper.snmp_open(sess.pointer)

    pdu = make_pdu

    response_ptr = FFI::MemoryPointer.new(:pointer)
     
    status = Net::SNMP::Wrapper.snmp_synch_response(sess.pointer, pdu.pointer, response_ptr)
     
    response = Net::SNMP::Wrapper::SnmpPdu.new(response_ptr.read_pointer)
    value = response.variables.val[:string].read_string

    status.should be(0)
    value.should match(/snmptest/)
  end

  it "wrapper should snmpget asynchronously" do
      sess = init_session
      pdu = make_pdu
      did_callback = 0
      result = nil
      sess.callback = lambda do |operation, session, reqid, pdu_ptr, magic|
        did_callback = 1
        pdu = Net::SNMP::Wrapper::SnmpPdu.new(pdu_ptr)
        variables = Net::SNMP::Wrapper::VariableList.new(pdu.variables)
        result = variables.val[:string].read_string
        0
      end
      sess = Net::SNMP::Wrapper.snmp_open(sess.pointer)
      Net::SNMP::Wrapper.snmp_send(sess.pointer, pdu)

      fdset = Net::SNMP::Wrapper.get_fd_set
      fds = FFI::MemoryPointer.new(:int)
      tval = Net::SNMP::Wrapper::TimeVal.new
      block = FFI::MemoryPointer.new(:int)
      block.write_int(1)
      Net::SNMP::Wrapper.snmp_select_info(fds, fdset, tval.pointer, block )
      Net::SNMP::Wrapper.select(fds.read_int, fdset, nil, nil, nil)
      Net::SNMP::Wrapper.snmp_read(fdset)
      did_callback.should be(1)
      result.should match(/snmptest/)
  end
end
