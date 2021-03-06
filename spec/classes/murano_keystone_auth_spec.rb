require 'spec_helper'

describe 'murano::keystone::auth' do

  shared_examples_for 'murano keystone auth' do

    describe 'with default class parameters' do
      let :params do
        { :password => 'murano_password',
          :tenant   => 'foobar' }
      end

      it { is_expected.to contain_keystone_user('murano').with(
                              :ensure   => 'present',
                              :password => 'murano_password',
                          ) }

      it { is_expected.to contain_keystone_user_role('murano@foobar').with(
                              :ensure  => 'present',
                              :roles   => ['admin']
                          )}

      it { is_expected.to contain_keystone_service('murano::application-catalog').with(
                              :ensure      => 'present',
                              :description => 'Murano Application Catalog'
                          ) }

      it { is_expected.to contain_keystone_endpoint('RegionOne/murano::application-catalog').with(
                              :ensure       => 'present',
                              :public_url   => "http://127.0.0.1:8082",
                              :admin_url    => "http://127.0.0.1:8082",
                              :internal_url => "http://127.0.0.1:8082"
                          ) }
    end

    describe 'with endpoint parameters' do
      let :params do
        { :password     => 'murano_password',
          :public_url   => 'https://10.10.10.10:80',
          :internal_url => 'http://10.10.10.11:81',
          :admin_url    => 'http://10.10.10.12:81' }
      end

      it { is_expected.to contain_keystone_endpoint('RegionOne/murano::application-catalog').with(
                              :ensure       => 'present',
                              :public_url   => 'https://10.10.10.10:80',
                              :internal_url => 'http://10.10.10.11:81',
                              :admin_url    => 'http://10.10.10.12:81'
                          ) }
    end

    describe 'when overriding auth and service name' do
      let :params do
        { :password => 'foo',
          :service_name => 'muranoy',
          :auth_name => 'muranoy' }
      end

      it { is_expected.to contain_keystone_user('muranoy') }
      it { is_expected.to contain_keystone_user_role('muranoy@services') }
      it { is_expected.to contain_keystone_service('muranoy::application-catalog') }
      it { is_expected.to contain_keystone_endpoint('RegionOne/muranoy::application-catalog') }
    end

    describe 'when not configuring user and role' do
      let :params do
        { :password => 'foo',
          :configure_user => false,
          :configure_user_role => false }
      end

      it { is_expected.to_not contain_keystone_user('murano') }
      it { is_expected.to_not contain_keystone_user_role('murano@services') }
    end
  end

  on_supported_os({
    :supported_os   => OSDefaults.get_supported_os
  }).each do |os,facts|
    context "on #{os}" do
      let (:facts) do
        facts.merge!(OSDefaults.get_facts())
      end

      it_behaves_like 'murano keystone auth'
    end
  end

end
