-- =====================================================================
-- Orwickle database — 007: real-time chat and in-app notifications   (Features 7, 8)
-- Delivered live with Socket.IO; stored here as history.
-- =====================================================================

-- One conversation per approved access request; exactly two participants.
CREATE TABLE conversations (
  id                         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  access_request_id          uuid NOT NULL UNIQUE,
  listing_id                 uuid NOT NULL,
  owner_id                   uuid NOT NULL,
  counterparty_id            uuid NOT NULL,
  owner_last_read_at         timestamptz,
  counterparty_last_read_at  timestamptz,
  last_message_at            timestamptz,
  created_at                 timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (access_request_id, listing_id, owner_id, counterparty_id)
    REFERENCES access_requests (id, listing_id, owner_id, requester_id)
);
CREATE INDEX conversations_owner_idx        ON conversations (owner_id, last_message_at DESC);
CREATE INDEX conversations_counterparty_idx ON conversations (counterparty_id, last_message_at DESC);

CREATE TABLE messages (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id  uuid NOT NULL REFERENCES conversations (id),
  sender_id        uuid NOT NULL REFERENCES users (id),
  body             text NOT NULL CHECK (char_length(body) BETWEEN 1 AND 4000),
  hidden_at        timestamptz,                       -- hidden by admin moderation
  hidden_by        uuid REFERENCES users (id),
  created_at       timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX messages_conversation_idx ON messages (conversation_id, created_at DESC);

-- Sender must be one of the two participants.
CREATE FUNCTION messages_check_sender() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM conversations c
    WHERE c.id = NEW.conversation_id AND NEW.sender_id IN (c.owner_id, c.counterparty_id)
  ) THEN
    RAISE EXCEPTION 'sender is not a participant of this conversation' USING ERRCODE = 'check_violation';
  END IF;
  UPDATE conversations SET last_message_at = NEW.created_at WHERE id = NEW.conversation_id;
  RETURN NEW;
END $$;

CREATE TRIGGER messages_check_sender BEFORE INSERT ON messages
  FOR EACH ROW EXECUTE FUNCTION messages_check_sender();

-- In-app notifications (no third-party push).
-- type examples: access_request.new, access_request.approved, offer.new, offer.countered,
-- offer.accepted, agreement.new_version, agreement.acknowledged, message.new, report.resolved,
-- review.decision
CREATE TABLE notifications (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  type         text NOT NULL,
  title        text NOT NULL,
  body         text,
  entity_type  text,           -- e.g. 'offer', 'access_request', 'agreement'
  entity_id    uuid,
  data         jsonb NOT NULL DEFAULT '{}',
  read_at      timestamptz,
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX notifications_user_idx   ON notifications (user_id, created_at DESC);
CREATE INDEX notifications_unread_idx ON notifications (user_id) WHERE read_at IS NULL;
