module UsersHelper

  def user_link(user)
    if user.name.blank?
      link_to user.login, user_path(user)
    else
      link_to h(user.name), user_path(user)
    end
  end

  def show_user_password_fields
    update_page do |page|
      page['change_password_link'].hide
      page['password_fields'].show
      page['user_password'].focus
    end
  end
  
  def user_rss_token(url, filter = nil)
    filter_param = filter.present? ? "&filter=#{filter}" : ""
    url + "?rss_token=#{current_user.rss_token}#{current_user.id}#{filter_param}"
  end
  
  def avatar_or_gravatar(user, size)
    user.avatar_or_gravatar_path(size, request.ssl?).tap do |url|
      unless url.starts_with? 'http'
        url.replace(root_url.chomp('/') + url)
        url.sub! 'http:', 'https:' if request.ssl?
      end
    end
  end
  
  def gravatar_url
    "<a href='http://gravatar.com'>Gravatar</a>".html_safe
  end
  
  def build_user_phone_number(user)
    card = user.card || user.build_card
    card.phone_numbers.build unless card.phone_numbers.any?
  end
  
  def load_javascript_user_data
    javascript_tag %(
      my_user = #{json_user};
      my_projects = #{json_projects};
      my_external_organizations = #{json_external_organizations};
      my_organizations = #{json_organizations};
      current_project = #{@current_project ? @current_project.id : 'null'};
    )
  end
  
  def load_my_avatar_for_new_comments
    %(<style type='text/css'>
        a.micro_avatar.my_avatar { background: url(#{avatar_or_gravatar(current_user, :micro)}) no-repeat }
      </style>).html_safe
  end

  def js_for_signup_form_validations
    error_messages = 
      %w(too_long too_short empty invalid confirmation).inject({}) do |r,key|
        r[key] = t("activerecord.errors.messages.#{key}")
        r
      end
    strength_messages =
      %w(too_short weak average strong too_long).inject({}) do |r,key|
        r[key] = t("password_strength.#{key}")
        r
      end

    javascript_tag <<-EOS
    var FieldMessages = (#{error_messages.to_json})
    var StrengthMessages = (#{strength_messages.to_json})
    var FieldErrors = {
      add: function(input, message) {
        input.up('div').addClassName('field_with_errors')
        input.up('.text_field').down('.errors_for').innerHTML = message
        this.setSuccess(input, false)
      },
      clear: function(input) {
        if (input.up('.field_with_errors'))
          input.up('.field_with_errors').removeClassName('field_with_errors')
        input.up('.text_field').down('.errors_for').innerHTML = ""
        this.setSuccess(input, true)
      },
      setSuccess: function(input, status) {
        var icon = input.up('.text_field').down('.result_icon')
        if (!icon) {
          var icon = new Element('div', { 'class': 'result_icon' })
          input.insert({after: icon})
        }
        icon.className = 'result_icon ' + (status ? 'static_tick_icon' : 'static_cross_icon')
      },
      displayStrength: function(input) {
        this.clear(input);
        var password = input.value
        var score = 0;
        if (password.match(/[!,@,#,$,%,^,&,*,?,_,~]/)) score += 1;
        if (password.match(/([a-z])/)) score += 1;
        if (password.match(/([A-Z])/)) score += 1;
        if (password.match(/([0-9])/)) score += 1;
        if (password.length >= 8) score += 2;
        if (password.length >= 10) score += 2;

        var strength = "average";
        if (score < 3) strength = "weak";
        if (score > 5) strength = "strong";

        var message_field = input.up('.text_field').down('.errors_for');
        message_field.innerHTML = StrengthMessages[strength];
        message_field.className = "errors_for "+strength
      }
    }

    document.on('change', '#user_first_name, #user_last_name', function(e,input) {
      if(input.value.length > 20) {
        FieldErrors.add(input, FieldMessages.too_long.gsub('%{count}',20))
      } else if (input.value.length < 1) {
        FieldErrors.add(input, FieldMessages.empty)
      } else {
        FieldErrors.clear(input)
      }
    })

    document.on('change', '#user_login', function(e,input) {
      if(!input.value.match(/^[a-z0-9_]+$/i)) {
        FieldErrors.add(input, FieldMessages.invalid)
      } else if (input.value.length > 40) {
        FieldErrors.add(input, FieldMessages.too_long.gsub('%{count}',40))
      } else if (input.value.length < 3) {
        FieldErrors.add(input, FieldMessages.too_short.gsub('%{count}',3))
      } else {
        FieldErrors.clear(input)
      }
    })

    document.on('change', '#user_email', function(e,input) {
      if(!input.value.match(/^[\\w\\.%\\-]+@(?:[A-Z0-9\\-]+\\.)+(?:[A-Z]{2,3}|com|org|net|edu|gov|mil|biz|info|mobi|name|aero|jobs|coop|museum)$/i)) {
        FieldErrors.add(input, FieldMessages.invalid)
      } else if (input.value.length > 100) {
        FieldErrors.add(input, FieldMessages.too_long.gsub('%{count}',100))
      } else {
        FieldErrors.clear(input)
      }
    })

    document.on('keydown', '#user_password', function(e,input) {
      if (input.value.length < 6) {
        FieldErrors.add(input, StrengthMessages.too_short.gsub('%{count}',6))
      } else if (input.value.length > 40) {
        FieldErrors.add(input, StrengthMessages.too_long.gsub('%{count}',40))
      } else {
        FieldErrors.displayStrength(input)
      }
    }.debounce(200))

    document.on('keydown', '#user_password_confirmation', function(e,input) {
      if(input.value != $('user_password').value) {
        FieldErrors.add(input, FieldMessages.confirmation)
      } else {
        FieldErrors.clear(input)
      }
    }.debounce(200))
    EOS
  end

  def digest_select_options
    Person::DIGEST.collect {|option,index| [ t(".digest_option_#{option}"), index ] }.to_a.sort_by {|k,v| v }
  end

  protected

    def json_user
      {
        :id => current_user.id,
        :username => current_user.login, 
        :splash_screen => current_user.splash_screen,
        :collapse_activities => current_user.collapse_activities,
        :keyboard_shortcuts => !!current_user.settings["keyboard_shortcuts"],
        :first_day_of_week => current_user.first_day_of_week,
        :recent_projects => current_user.recent_projects_ids,
        :stats => {
          :projects => current_user.get_stat('projects'),
          :conversations => current_user.get_stat('conversations'),
          :tasks => current_user.get_stat('tasks'),
          :pages => current_user.get_stat('pages'),
          :invites => current_user.get_stat('invites')
        },
        :first_steps => current_user.show_first_steps,
        :badges => current_user.badges,
        :show_badges => current_user.show_badges,
        :can_create_project => (!Teambox.config.community || (@community_organization && @community_role)),
        :community => Teambox.config.community
      }.to_json
    end

    def json_projects
      projects = {}
      project_ids = current_user.project_ids + [@current_project.try(:id)]
      my_projects = Project.where(:id => project_ids).joins(:people, "AND people.user_id = #{current_user.id}").except(:select).select("projects.id, projects.permalink, projects.organization_id, projects.user_id, projects.archived, projects.tracks_time, projects.name, people.role")
      my_projects.each do |p|
        projects[p.id] = {
          :permalink => p.permalink,
          :role => p.role,
          :organization_id => p.organization_id,
          :owner => p.user_id,
          :archived => p.archived,
          :time_tracking => p.tracks_time,
          :name => h(p.name) }
      end
      projects.to_json
    end

    # FIXME refactor the next two methods in one
    def json_external_organizations
      current_user.projects.joins(:organization).
        except(:select).except(:order).
        select('distinct(organizations.id), organizations.name, organizations.permalink').
        collect(&:attributes).to_json
    end

    def json_organizations
      Rails.cache.fetch("json_organizations.#{current_user.id}") do
        Organization.json_organizations(current_user)
      end.to_json
    end
end
