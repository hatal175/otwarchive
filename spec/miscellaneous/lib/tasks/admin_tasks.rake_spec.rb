require 'spec_helper'
require 'rake'

describe "admin rake tasks" do
  before do
    # Code for activating rake, adapted from:
    # spec/miscellaneous/lib/tasks/resque.rake_spec.rb
    @rake = Rake.application
    @rake.init
    @rake.load_rakefile
  end

  after do
    @rake.clear
  end

  describe "purging unconfirmed users" do
    context "when the unconfirmed account is younger than two weeks" do
      it "doesn't delete the account" do
        unconfirmed = Delorean.time_travel_to 13.days.ago do
          create(:user)
        end

        @rake["admin:purge_unvalidated_users"].execute

        expect { unconfirmed.reload }.not_to raise_exception
      end
    end

    context "when the unconfirmed account is older than two weeks" do
      it "deletes the account" do
        unconfirmed = Delorean.time_travel_to 15.days.ago do
          create(:user)
        end

        @rake["admin:purge_unvalidated_users"].execute

        expect { unconfirmed.reload }.to \
          raise_exception(ActiveRecord::RecordNotFound)
      end

      it "resets the account's invitation" do
        invitation = create(:invitation)

        unconfirmed = Delorean.time_travel_to 15.days.ago do
          create(:user, invitation_token: invitation.token)
        end

        invitation.reload
        expect(invitation.redeemed_at).not_to be_nil
        expect(invitation.invitee).to eq(unconfirmed)

        @rake["admin:purge_unvalidated_users"].execute

        invitation.reload
        expect(invitation.redeemed_at).to be_nil
        expect(invitation.invitee).to be_nil
      end
    end
  end
end