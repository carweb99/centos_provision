require 'spec_helper'

RSpec.describe 'ssl_enabler.sh' do
  let(:env) { {LANG: 'C'} }
  let(:options) { '' }
  let(:args) { options + ' ' + domains.join(' ') }
  let(:docker_image) { nil }
  let(:command_stubs) { {} }
  let(:all_command_stubs) { {nginx: '/bin/true', certbot: '/bin/true', crontab: '/bin/true'} }
  let(:commands) { [] }
  let(:domains) { %w[domain1.tld] }
  let(:nginx_conf) { "ssl_certificate /etc/nginx/cert.pem;\nssl_certificate_key /etc/nginx/ssl/privkey.pem;" }
  let(:make_proper_nginx_conf) do
    [
      'mkdir -p /etc/nginx/conf.d /etc/nginx/ssl',
      'touch /etc/nginx/ssl/{cert,privkey}.pem',
      %Q{echo -e "#{nginx_conf}"> /etc/nginx/conf.d/vhosts.conf}
    ]
  end

  let(:prompts) do
    {
      en: {
        ssl_agree_tos: "Do you agree with terms of Let's Encrypt Subscriber Agreement?",
        ssl_email: 'Please enter your email (you can left this field empty)',
      },
      ru: {
        ssl_agree_tos: "Вы согласны с условиями Абонентского Соглашения Let's Encrypt?",
        ssl_email: 'Укажите email (можно не указывать)',
      }
    }
  end

  let(:user_values) do
    {
      ssl_agree_tos: 'yes',
      ssl_email: '',
    }
  end

  let(:en_prompts_with_values) do
    {
      prompts[:en][:ssl_agree_tos] => user_values[:ssl_agree_tos],
      prompts[:en][:ssl_email] => user_values[:ssl_email],
    }
  end

  let(:ru_prompts_with_values) do
    {
      prompts[:ru][:ssl_agree_tos] => user_values[:ssl_agree_tos],
      prompts[:ru][:ssl_email] => user_values[:ssl_email],
    }
  end

  let(:prompts_with_values) { en_prompts_with_values }

  let(:ssl_enabler) do
    SslEnabler.new env: env,
                   args: args,
                   prompts_with_values: prompts_with_values,
                   docker_image: docker_image,
                   command_stubs: command_stubs,
                   commands: commands
  end

  shared_examples_for 'should print to log' do |expected_texts|
    it "prints to stdout #{expected_texts.inspect}" do
      ssl_enabler.call(current_dir: @current_dir)
      [*expected_texts].each do |expected_text|
        expect(ssl_enabler.log).to match(expected_text)
      end
    end
  end

  shared_examples_for 'should print to stdout' do |expected_text|
    it "prints to stdout #{expected_text.inspect}" do
      ssl_enabler.call
      expect(ssl_enabler.stdout).to match(expected_text)
    end
  end

  shared_examples_for 'should not print to stdout' do |expected_text|
    it "does not print to stdout #{expected_text.inspect}" do
      ssl_enabler.call
      expect(ssl_enabler.stdout).not_to match(expected_text)
    end
  end

  shared_examples_for 'should exit with error' do |error_texts|
    it "exits with error #{error_texts.inspect}" do
      ssl_enabler.call
      expect(ssl_enabler.ret_value).not_to be_success
      [*error_texts].each do |error_text|
        expect(ssl_enabler.stderr).to match(error_text)
      end
    end
  end

  describe 'checking bash pipe mode' do
    let(:options) { '-s -p' }

    it_behaves_like 'should print to log', "Can't detect pipe bash mode. Stdin hack disabled"
  end

  describe 'invoked' do
    context 'with wrong options' do
      let(:options) { '-x' }

      it_behaves_like 'should exit with error', "Usage: #{SslEnabler::SSL_ENABLER_CMD}"
    end

    context 'without domains' do
      let(:domains) { [] }

      it_behaves_like 'should exit with error', "Usage: #{SslEnabler::SSL_ENABLER_CMD}"
    end

    context 'with `-l` option' do
      let(:options) { "-l #{lang}" }

      context 'with `en` value' do
        let(:lang) { 'en' }
        it_behaves_like 'should print to log', 'Language: en'
      end

      context 'with `ru` value' do
        let(:lang) { 'ru' }

        it_behaves_like 'should print to log', 'Language: ru'
      end

      context 'with unsupported value' do
        let(:lang) { 'xx' }

        it_behaves_like 'should exit with error', 'Specified language "xx" is not supported'
      end
    end

    # TODO: Detect language from LC_MESSAGES
    describe 'detects language from LANG environment variable' do
      context 'LANG=ru_RU.UTF-8' do
        let(:env) { {LANG: 'ru_RU.UTF-8'} }

        it_behaves_like 'should print to log', 'Language: ru'
      end

      context 'LANG=ru_UA.UTF-8' do
        let(:env) { {LANG: 'ru_UA.UTF-8'} }

        it_behaves_like 'should print to log', 'Language: ru'
      end

      context 'LANG=en_US.UTF-8' do
        let(:env) { {LANG: 'en_US.UTF-8'} }

        it_behaves_like 'should print to log', 'Language: en'
      end

      context 'LANG=de_DE.UTF-8' do
        let(:env) { {LANG: 'de_DE.UTF-8'} }

        it_behaves_like 'should print to log', 'Language: en'
      end
    end
  end

  describe 'fields' do
    # `-s` option disables cerbot/nginx conf checks
    # `-p` option disables invoking certbot command

    let(:options) { '-spl en' }

    describe 'should support russian prompts' do
      let(:options) { '-sp -l ru' }
      let(:prompts_with_values) { ru_prompts_with_values }

      it 'stdout contains prompt with default value' do
        ssl_enabler.call
        expect(ssl_enabler.stdout).to include(prompts[:ru][:ssl_agree_tos])
      end
    end

    describe 'should show default value' do
      it 'stdout contains prompt with default value' do
        ssl_enabler.call
        expect(ssl_enabler.stdout).to include("#{prompts[:en][:ssl_agree_tos]} [no] >")
      end
    end
  end

  context 'without actual running commands' do
    let(:options) { '-p' }

    before(:all) { `docker rm keitaro_ssl_enabler_test &>/dev/null` }

    shared_examples_for 'should enable ssl for Keitaro TDS' do
      it_behaves_like 'should print to stdout',
                      'certbot certonly --webroot'
    end

    context 'nginx is installed, certbot is installed, crontab is installed, nginx is configured properly' do
      let(:docker_image) { 'centos' }

      let(:command_stubs) { all_command_stubs }

      let(:commands) { make_proper_nginx_conf }

      it_behaves_like 'should print to log', [
        "Try to found nginx\nOK",
        "Try to found crontab\nOK",
        "Try to found certbot\nOK",
        "Checking /etc/nginx/conf.d/vhosts.conf existence\nOK",
        "Checking ssl params in /etc/nginx/conf.d/vhosts.conf\nOK"
      ]

      it_behaves_like 'should enable ssl for Keitaro TDS'
    end

    context 'nginx is not installed' do
      let(:docker_image) { 'centos' }
      let(:command_stubs) { {certbot: '/bin/true', crontab: '/bin/true'} }

      it_behaves_like 'should print to log', "Try to found nginx\nNOK"

      it_behaves_like 'should exit with error', 'Your Keitaro TDS installation does not properly configured'
    end

    context 'crontab is not installed' do
      let(:docker_image) { 'centos' }

      let(:command_stubs) { {nginx: '/bin/true', certbot: '/bin/true'} }

      it_behaves_like 'should print to log', "Try to found crontab\nNOK"

      it_behaves_like 'should exit with error', 'Your Keitaro TDS installation does not properly configured'
    end

    context 'certbot is not installed' do
      let(:docker_image) { 'centos' }
      let(:command_stubs) { {nginx: '/bin/true', crontab: '/bin/true'} }

      it_behaves_like 'should print to log', "Try to found certbot\nNOK"

      it_behaves_like 'should exit with error', 'Nginx settings of your Keitaro TDS installation does not properly configured'
    end

    context 'certbot is installed, vhosts.conf is absent' do
      let(:docker_image) { 'centos' }

      let(:command_stubs) { all_command_stubs }

      it_behaves_like 'should print to log', [
        "Try to found certbot\nOK",
        "Checking /etc/nginx/conf.d/vhosts.conf existence\nNOK",
      ]

      it_behaves_like 'should exit with error', 'Nginx settings of your Keitaro TDS installation does not properly configured'
    end

    context 'programs are installed, nginx is not configured properly' do
      let(:docker_image) { 'centos' }
      let(:command_stubs) { all_command_stubs }

      let(:nginx_conf) { "listen 80;" }

      let(:commands) { make_proper_nginx_conf }

      it_behaves_like 'should print to log', [
        "Try to found certbot\nOK",
        "Checking /etc/nginx/conf.d/vhosts.conf existence\nOK",
        "Checking ssl params in /etc/nginx/conf.d/vhosts.conf\nNOK"
      ]

      it_behaves_like 'should exit with error', 'Nginx settings of your Keitaro TDS installation does not properly configured'
    end
  end

  describe 'enable-ssl result' do
    let(:docker_image) { 'centos' }
    let(:command_stubs) { all_command_stubs }
    let(:commands) { make_proper_nginx_conf }

    context 'successful running certbot' do
      it_behaves_like 'should print to stdout', /Everything done!/
    end

    context 'unsuccessful running certbot' do
      let(:command_stubs) { all_command_stubs.merge(certbot: '/bin/false') }

      it_behaves_like 'should exit with error', [
                                                  'There was an error evaluating command `certbot',
                                                  'Evaluating log saved to enable-ssl.log',
                                                  'Please rerun `enable-ssl.sh domain1.tld`'
                                                ]
    end
  end

  context 'with agree LE SA option specified' do
    let(:options) { '-s -p -a' }

    it_behaves_like 'should not print to stdout', "Do you agree with terms of Let's Encrypt Subscriber Agreement?"

    it_behaves_like 'should print to stdout', 'Everything done!'
  end

  context 'email specified' do
    let(:options) { '-s -p -e some.mail@example.com' }

    it_behaves_like 'should not print to stdout', 'Please enter your email'

    it_behaves_like 'should print to stdout', /certbot certonly .* --email some.mail@example.com/
  end

  context 'without email option specified' do
    let(:options) { '-s -p -w' }

    it_behaves_like 'should not print to stdout', 'Please enter your email'

    it_behaves_like 'should print to stdout', /certbot certonly .* --register-unsafely-without-email/
  end

  describe 'check running under non-root' do
    it_behaves_like 'should exit with error', 'You must run this program as root'
  end

  describe 'making symlinks' do
    let(:options) { '-s -p' }

    it_behaves_like 'should print to log', 'rm -f /etc/nginx/ssl/cert.pem'
    it_behaves_like 'should print to log', 'ln -s /etc/letsencrypt/live/domain1.tld/fullchain.pem /etc/nginx/ssl/cert.pem'
    it_behaves_like 'should print to log', 'rm -f /etc/nginx/ssl/privkey.pem'
    it_behaves_like 'should print to log', 'ln -s /etc/letsencrypt/live/domain1.tld/privkey.pem /etc/nginx/ssl/privkey.pem'
  end

  describe 'logging' do
    around do |example|
      Dir.mktmpdir('', '/tmp') do |current_dir|
        Dir.chdir(current_dir) do
          @current_dir = current_dir
          example.run
        end
      end
    end

    shared_examples_for 'should create' do |filename|
      specify do
        ssl_enabler.call(current_dir: @current_dir)
        expect(File).to be_exists(filename)
      end
    end

    shared_examples_for 'should move old enable-ssl.log to' do |newname|
      specify do
        old_content = IO.read('enable-ssl.log')
        ssl_enabler.call(current_dir: @current_dir)
        expect(IO.read(newname)).to eq(old_content)
      end
    end

    context 'log files does not exists' do
      it_behaves_like 'should create', 'enable-ssl.log'
    end

    context 'enable-ssl.log exists' do
      before { IO.write('enable-ssl.log', 'some log') }

      it_behaves_like 'should create', 'enable-ssl.log'

      it_behaves_like 'should move old enable-ssl.log to', 'enable-ssl.log.1'
    end

    context 'enable-ssl.log, enable-ssl.log.1 exists' do
      before { IO.write('enable-ssl.log', 'some log') }
      before { IO.write('enable-ssl.log.1', 'some log.1') }

      it_behaves_like 'should create', 'enable-ssl.log'

      it_behaves_like 'should move old enable-ssl.log to', 'enable-ssl.log.2'
    end
  end

  describe 'adding cron task' do
    let(:docker_image) { 'centos' }
    let(:command_stubs) { all_command_stubs }
    let(:commands) { make_proper_nginx_conf }

    it_behaves_like 'should print to log', /Adding renewal cron job/

    context 'cron job already exists' do

      let(:commands) do
        make_proper_nginx_conf +
        [
          'echo "echo certbot renew --allow-subset-of-names --quiet" > /bin/crontab',
          'chmod a+x /bin/crontab'
        ]
      end

      it_behaves_like 'should print to log', /Renewal cron job already exists/
    end
  end

  describe 'reloading nginx' do
    let(:options) { '-s -p' }

    it_behaves_like 'should print to log', /nginx -s reload/
  end
end