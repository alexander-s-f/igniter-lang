module Proof.EffectSurface.ReceiptFailure

type AuditReceipt {
  note: Text
}

effect contract RecordOnly {
  receipt AuditReceipt
}
