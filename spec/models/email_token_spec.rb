require 'spec_helper'

describe EmailToken do

  it { is_expected.to validate_presence_of :user_id }
  it { is_expected.to validate_presence_of :email }
  it { is_expected.to belong_to :user }


  context '#create' do
    let(:user) { Fabricate(:user, active: false) }
    let!(:original_token) { user.email_tokens.first }
    let!(:email_token) { user.email_tokens.create(email: 'bubblegum@adevnturetime.ooo') }

    it 'should create the email token' do
      expect(email_token).to be_present
    end

    it 'should downcase the email' do
      token = user.email_tokens.create(email: "UpperCaseSoWoW@GMail.com")
      expect(token.email).to eq "uppercasesowow@gmail.com"
    end

    it 'is valid' do
      expect(email_token).to be_valid
    end

    it 'has a token' do
      expect(email_token.token).to be_present
    end

    it 'is not confirmed' do
      expect(email_token).to_not be_confirmed
    end

    it 'is not expired' do
      expect(email_token).to_not be_expired
    end

    it 'marks the older token as expired' do
      original_token.reload
      expect(original_token).to be_expired
    end
  end

  context '#confirm' do

    let(:user) { Fabricate(:user, active: false) }
    let(:email_token) { user.email_tokens.first }

    it 'returns nil with a nil token' do
      expect(EmailToken.confirm(nil)).to be_blank
    end

    it 'returns nil with a made up token' do
      expect(EmailToken.confirm(EmailToken.generate_token)).to be_blank
    end

    it 'returns nil unless the token is the right length' do
      expect(EmailToken.confirm('a')).to be_blank
    end

    it 'returns nil when a token is expired' do
      email_token.update_column(:expired, true)
      expect(EmailToken.confirm(email_token.token)).to be_blank
    end

    it 'returns nil when a token is older than a specific time' do
      SiteSetting.email_token_valid_hours = 10
      email_token.update_column(:created_at, 11.hours.ago)
      expect(EmailToken.confirm(email_token.token)).to be_blank
    end

    context 'taken email address' do

      before do
        @other_user = Fabricate(:coding_horror)
        email_token.update_attribute :email, @other_user.email
      end

      it 'returns nil when the email has been taken since the token has been generated' do
        expect(EmailToken.confirm(email_token.token)).to be_blank
      end

    end

    context 'welcome message' do
      it 'sends a welcome message when the user is activated' do
        user = EmailToken.confirm(email_token.token)
        expect(user.send_welcome_message).to eq true
      end

      context "when using the code a second time" do

        it "doesn't send the welcome message" do
          SiteSetting.email_token_grace_period_hours = 1
          EmailToken.confirm(email_token.token)
          user = EmailToken.confirm(email_token.token)
          expect(user.send_welcome_message).to eq false
        end
      end

    end

    context 'success' do

      let!(:confirmed_user) { EmailToken.confirm(email_token.token) }

      it "returns the correct user" do
        expect(confirmed_user).to eq user
      end

      it 'marks the user as active' do
        confirmed_user.reload
        expect(confirmed_user).to be_active
      end

      it 'marks the token as confirmed' do
        email_token.reload
        expect(email_token).to be_confirmed
      end

      it "can be confirmed again" do
        EmailToken.stubs(:confirm_valid_after).returns(1.hour.ago)

        expect(EmailToken.confirm(email_token.token)).to eq user

        # Unless `confirm_valid_after` has passed
        EmailToken.stubs(:confirm_valid_after).returns(1.hour.from_now)
        expect(EmailToken.confirm(email_token.token)).to be_blank
      end
    end
  end

end

