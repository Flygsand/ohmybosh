module Bosh
  module Helpers
    module XMPP

      # promiscuous JID regex
      JID_REGEX = /^([^\s]+)@([^\s\/]+)(?:\/([^\s]+))?/

      def split_jid(jid)
        Hash[*[:node, :domain, :resource].zip(jid.scan(JID_REGEX).flatten).flatten]
      end

      def bare_jid(jid)
        jid[:node] + '@' + jid[:domain]
      end

      def full_jid(jid)
        bare_jid(jid) + '/' + jid[:resource]
      end
    end
  end
end
