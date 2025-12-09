class Transfer < ApplicationRecord
  belongs_to :sender, class_name: 'User', foreign_key: 'sender_id'
  belongs_to :receiver, class_name: 'User', foreign_key: 'receiver_id'
  
  # Валідація sender: обов'язкове поле
  validates :sender_id, presence: true
  validates :sender, presence: true
  
  # Валідація receiver: обов'язкове поле
  validates :receiver_id, presence: true
  validates :receiver, presence: true
  
  # Валідація amount: обов'язкове поле, має бути числом більше 0
  validates :amount, presence: true, numericality: { greater_than: 0 }
  
  validates :status, inclusion: { in: %w[pending completed cancelled] }
  validate :sender_has_enough_balance, on: :create
  validate :cannot_transfer_to_self
  validate :sender_nickname_length
  
  after_initialize :set_default_status, if: :new_record?
  before_create :deduct_from_sender
  before_update :handle_status_change
  
  def set_default_status
    self.status ||= 'pending'
  end
  
  def pending?
    status == 'pending'
  end
  
  def completed?
    status == 'completed'
  end
  
  def cancelled?
    status == 'cancelled'
  end
  
  private
  
  def sender_has_enough_balance
    if sender && !sender.can_transfer?(amount)
      errors.add(:amount, "Недостатньо коштів на балансі. Доступно: #{sender.balance}₴")
    end
  end
  
  def cannot_transfer_to_self
    if sender_id == receiver_id
      errors.add(:receiver_id, "Не можна переказувати кошти самому собі")
    end
  end
  
  def sender_nickname_length
    if sender && sender.nickname && sender.nickname.length < 2
      errors.add(:sender, "має мати nickname мінімум 2 символи")
    end
  end
  
  def deduct_from_sender
    if pending? && sender && sender.can_transfer?(amount)
      sender.balance = (sender.balance || 0) - amount
      sender.save
    end
  end
  
  def handle_status_change
    return unless status_changed?
    
    old_status = status_was || 'pending'
    
    if status == 'completed' && old_status == 'pending'
      receiver.balance = (receiver.balance || 0) + amount
      receiver.save
    elsif status == 'cancelled' && old_status == 'pending'
      sender.balance = (sender.balance || 0) + amount
      sender.save
    end
  end
end

