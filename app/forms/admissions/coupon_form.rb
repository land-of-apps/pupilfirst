module Admissions
  class CouponForm < Reform::Form
    property :code, virtual: true, validates: { presence: true }
    property :founder_email, virtual: true

    validate :code_must_be_valid
    validate :founder_must_be_msp, if: :msp_coupon_applied?

    def code_must_be_valid
      errors[:code] << 'code not valid' unless coupon.present? && coupon.still_valid?
    end

    def founder_must_be_msp
      errors[:code] << 'code only valid for Microsoft Student Partners' unless founder_has_msp_email?
    end

    def apply_coupon!(startup)
      CouponUsage.create!(coupon: coupon, startup: startup)
    end

    def prepopulate!(founder)
      self.founder_email = founder&.email
    end

    private

    def coupon
      Coupon.find_by(code: code)
    end

    def msp_coupon_applied?
      return false if coupon.blank?
      coupon.coupon_type == Coupon::TYPE_MSP
    end

    def founder_has_msp_email?
      (founder_email =~ /@studentpartner.com\z/).present?
    end
  end
end