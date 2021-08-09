<?php

/**
 * @file
 * Enables modules and site configuration for a ek site installation.
 */

use Drupal\user\Entity\User;
use Drupal\Core\Form\FormStateInterface;
use Drupal\features\FeaturesManagerInterface;
use Drupal\features\ConfigurationItem;

/**
 * Implements hook_install_tasks().
 */
function ek_install_tasks(&$install_state) {
  $tasks = [
    'ek_install_profile_modules' => [
      'display_name' => t('Install EK modules'),
      'type' => 'batch',
    ],
    'ek_optional_setup' => [
      'display_name' => t('Install optional modules'),
      'type' => 'batch',
      'display' => TRUE,
    ],
    /*'ek_external_db_setup' => [
      'display_name' => t('Install external database'),
      'type' => 'batch',
      'display' => TRUE,
    ],*/
    'ek_theme_setup' => [
      'display_name' => t('Apply theme'),
      'display' => TRUE,
    ],
  ];
  return $tasks;
}

/**
 * Implements hook_install_tasks_alter().
 *
 * alter the verify requirements.
 * This is because of https://www.drupal.org/node/1253774. The dependencies of
 * dependencies are not tested. So adding requirements to our install profile
 * hook_requirements will not work :(. Also take a look at install.inc function
 * drupal_check_profile() it just checks for all the dependencies of our
 * install profile from the info file. And no actually hook_requirements in
 * there.
 */
function ek_install_tasks_alter(&$tasks, $install_state) {
  // Override the core install_verify_requirements task function.
  $tasks['install_verify_requirements']['function'] = 'ek_verify_custom_requirements';
  // Override the core finished task function.
  $tasks['install_finished']['function'] = 'ek_install_finished';
}

/**
 * Callback for install_verify_requirements, so that we meet custom requirement.
 *
 * @param array $install_state
 *   The current install state.
 *
 * @return array
 *   All the requirements we need to meet.
 */
function ek_verify_custom_requirements(array &$install_state) {
  
}

/**
 * Implements hook_form_FORM_ID_alter() for install_settings_form().
 *
 * Allows the profile to alter the site settings form.
 */
function ek_form_install_settings_form_alter (&$form, FormStateInterface $form_state) {
  
  /*Add fields for external DB
  $form['ek_profile']['external_database'] = [
      '#type' => 'textfield',
      '#title' => t('External database name'),
      '#default_value' => '',
      '#size' => 45,
      '#required' => TRUE,
      
    ];
   * @TODO insert external database form
   */
}

/**
 * Implements hook_form_FORM_ID_alter() for install_configure_form().
 *
 * Allows the profile to alter the site configuration form.
 */
function ek_form_install_configure_form_alter(&$form, FormStateInterface $form_state) {

    // Add 'EK' fieldset and options.
  $form['ek_profile'] = [
    '#type' => 'fieldgroup',
    '#title' => t('EK optional configuration'),
    '#description' => t('All the required modules and configuration will be automatically installed and imported. You can optionally select additional modules.'),
    '#weight' => 50,
  ];

  $ek_optional_modules = [
    'ek_projects' => t('Projects functionality'),
    'ek_sales' => t('Sales functionality that integrates also with Finance & Projects modules'),
    'ek_finance' => t('Finance functionality'),  
    'ek_messaging' => t('Messaging functionality that integrates also with Projects module'),
    'ek_products' => t('Products and services functionality that integrates also with Logistics & Sales modules'),
    'ek_documents' => t('Documents storage functionality that integrates also with Projects module'),
    'ek_intelligence' => t('Reports drafting functionality that integrates also with Projects module'),
    'ek_logistics' => t('Logistics functionality that integrates also with Projects & Sales modules'),  
    'ek_hr' => t('HR functionality that integrates also with Finance module'),
    'ek_assets' => t('Assets functionality that integrates also with Finance module'),
  ];

  // Checkboxes to enable Optional modules.
  $form['ek_profile']['optional_modules'] = [
    '#type' => 'checkboxes',
    '#title' => t('Enable additional features'),
    '#options' => $ek_optional_modules,
    '#default_value' => [ ],
  ];
  
    // Submit handler to enable features.
  $form['#submit'][] = 'ek_features_submit';
  
}


/**
 * Submit handler.
 */
function ek_features_submit($form_id, &$form_state) {
  $optional_modules = array_filter($form_state->getValue('optional_modules'));
  \Drupal::state()->set('ek_install_optional_modules', $optional_modules);
  //\Drupal::state()->set('ek_install_demo_content', $form_state->getValue('demo_content'));
}

/**
 * Installs required modules via a batch process.
 *
 * @param array $install_state
 *   An array of information about the current installation state.
 *
 * @return array
 *   The batch definition.
 */
function ek_install_profile_modules(array &$install_state) {

  $files = \Drupal::service('extension.list.module')->getList();

  $modules = [
    'ek_admin' => 'ek_admin',
    'ek_address_book' => 'ek_address_book',
    
  ];
  $ek_modules = $modules;
  // Always install required modules first. Respect the dependencies between
  // the modules.
  $required = [];
  $non_required = [];

  // Add modules that other modules depend on.
  foreach ($modules as $module) {
    if ($files[$module]->requires) {
      $module_requires = array_keys($files[$module]->requires);
      // Remove the ek modules from required modules.
      $module_requires = array_diff_key($module_requires, $ek_modules);
      $modules = array_merge($modules, $module_requires);
    }
  }
  $modules = array_unique($modules);
  // Remove the ek modules from to install modules.
  $modules = array_diff_key($modules, $ek_modules);
  foreach ($modules as $module) {
    if (!empty($files[$module]->info['required'])) {
      $required[$module] = $files[$module]->sort;
    }
    else {
      $non_required[$module] = $files[$module]->sort;
    }
  }
  arsort($required);

  $operations = [];
  foreach ($required + $non_required + $ek_modules as $module => $weight) {
    $operations[] = [
      '_ek_install_module_batch',
      [[$module], $module],
    ];
  }

  $batch = [
    'operations' => $operations,
    'title' => t('Install EK modules'),
    'error_message' => t('The installation has encountered an error.'),
  ];
  return $batch;
}

/**
 * External database for EK profile.
 *
 * @param array $install_state
 *   The install state.
 *
 * @return array
 *   Batch settings.
 */
function ek_external_db_setup(array &$install_state) {
    
}

/**
 * Final setup of EK profile.
 *
 * @param array $install_state
 *   The install state.
 *
 * @return array
 *   Batch settings.
 */
function ek_optional_setup(array &$install_state) {
  // Clear all status messages generated by modules installed in previous step.
  \Drupal::messenger()->deleteByType('status');
  // There is no content at this point.
  node_access_needs_rebuild(FALSE);

  $batch = [];

  $ek_optional_modules = \Drupal::state()->get('ek_install_optional_modules');
  foreach ($ek_optional_modules as $module => $module_name) {
    $batch['operations'][] = [
      '_ek_install_module_batch',
      [[$module], $module_name],
    ];
  }
  /*
  $demo_content = \Drupal::state()->get('ek_install_demo_content');
  if ($demo_content === 1) {
    $batch['operations'][] = [
      '_ek_install_module_batch',
      [['ek_demo'], 'ek_demo'],
    ];

    // Generate demo content.
    $demo_content_types = [
    ];
    foreach ($demo_content_types as $demo_type => $demo_description) {
      $batch['operations'][] = [
        '_ek_add_demo_batch',
        [$demo_type, $demo_description],
      ];
    }
    
    // Uninstall ek_demo.
    $batch['operations'][] = [
      '_ek_uninstall_module_batch',
      [['ek_demo'], 'ek_demo'],
    ];
    
  }*/

  // Add some finalising steps.
  $final_batched = [
    'profile_weight' => t('Set weight of profile.'),
    'router_rebuild' => t('Rebuild router.'),
    'cron_run' => t('Run cron.'),
    'import_optional_config' => t('Import optional configuration'),
  ];
  foreach ($final_batched as $process => $description) {
    $batch['operations'][] = [
      '_ek_finalise_batch',
      [$process, $description],
    ];
  }

  return $batch;
}

/**
 * Install the theme.
 *
 * @param array $install_state
 *   The install state.
 */
function ek_theme_setup(array &$install_state) {
// Clear all status messages generated by modules installed in previous step.
  \Drupal::messenger()->deleteByType('status');
  
  //remove link in menu
  $menu_link_manager = \Drupal::service('plugin.manager.menu.link');
  $menu_link = $menu_link_manager->getDefinition('node.add_page');
  $menu_link['enabled'] = 0; 
  $menu_link_manager->updateDefinition('node.add_page', $menu_link);

  $themes = ['bartik'];
  \Drupal::service('theme_installer')->install($themes);

  \Drupal::configFactory()
    ->getEditable('system.theme')
    ->set('default', 'bartik')
    ->save();

  // Ensure that the install profile's theme is used.
  // @see _drupal_maintenance_theme()
  \Drupal::service('theme.manager')->resetActiveTheme();

    
}

/**
 * Performs final installation steps and displays a 'finished' page.
 *
 * @param array $install_state
 *   An array of information about the current installation state.
 *
 * @see install_finished()
 */
function ek_install_finished(array &$install_state) {
  // Clear all status messages generated by modules installed in previous step.
  \Drupal::messenger()->deleteByType('status');

  if ($install_state['interactive']) {
    // Load current user and perform final login tasks.
    // This has to be done after drupal_flush_all_caches()
    // to avoid session regeneration.
    $account = User::load(1);
    user_login_finalize($account);
  }
}

/**
 * Implements callback_batch_operation().
 *
 * Performs batch installation of modules.
 */
function _ek_install_module_batch($module, $module_name, &$context) {
  set_time_limit(0);
  \Drupal::service('module_installer')->install($module);
  $context['results'][] = $module;
  $context['message'] = t('Install %module_name module.', ['%module_name' => $module_name]);
}

/**
 * Implements callback_batch_operation().
 *
 * Performs batch uninstallation of modules.
 */
function _ek_uninstall_module_batch($module, $module_name, &$context) {
  set_time_limit(0);
  \Drupal::service('module_installer')->uninstall($module);
  $context['results'][] = $module;
  $context['message'] = t('Uninstalled %module_name module.', ['%module_name' => $module_name]);
}

/**
 * Implements callback_batch_operation().
 *
 * Performs batch demo content generation.
 */
function _ek_add_demo_batch($demo_type, $demo_description, &$context) {
    

}

/**
 * Implements callback_batch_operation().
 *
 * Performs batch finalising.
 */
function _ek_finalise_batch($process, $description, &$context) {

  switch ($process) {
    case 'profile_weight':
      $profile = \Drupal::installProfile();

      // Installation profiles are always loaded last.
      module_set_weight($profile, 1000);
      break;

    case 'router_rebuild':
      // Build the router once after installing all modules.
      // This would normally happen upon KernelEvents::TERMINATE, but since the
      // installer does not use an HttpKernel, that event is never triggered.
      \Drupal::service('router.builder')->rebuild();
      break;

    
  }

  $context['results'][] = $process;
  $context['message'] = $description;
}


